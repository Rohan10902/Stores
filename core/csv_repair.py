import csv
import copy
import os
import json

class CSVRepairTool:
    def __init__(self):
        self.headers = []
        self.rows = []
        self.issues = []
        self.history = []
        self.created_records = {}
        self.record_counter = 10000

    def _save_state(self):
        # Deepcopy the arrays and mapping to history for accurate undo
        self.history.append((copy.deepcopy(self.rows), copy.deepcopy(self.issues), copy.deepcopy(self.created_records)))

    def inspect_csv(self, path):
        self.headers = []
        self.rows = []
        self.issues = []
        self.history = []
        self.created_records = {}
        
        if not os.path.exists(path):
            return self._get_payload()
            
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            reader = csv.reader(f)
            try:
                self.headers = next(reader)
            except StopIteration:
                return self._get_payload()
            
            for row in reader:
                self.rows.append(row)
                
        self._recalculate_issues()
        return self._get_payload()

    def join_shifted_rows(self, issue_index):
        self._save_state()
        issue = next((i for i in self.issues if i['index'] == issue_index), None)
        if issue:
            r_idx = issue['row'] - 1
            if 0 <= r_idx < len(self.rows) - 1:
                # Real mutation: concatenate list values and delete the consumed next row
                self.rows[r_idx] = self.rows[r_idx] + self.rows[r_idx+1]
                del self.rows[r_idx+1]
                self._recalculate_issues()
        return self._get_payload()

    def apply_mapping(self, issue_index, col_index, target, remember):
        self._save_state()
        issue = next((i for i in self.issues if i['index'] == issue_index), None)
        if issue:
            r_idx = issue['row'] - 1
            row = self.rows[r_idx]
            
            # Real mutation: Remap a value from col_index to the target header index
            if target in self.headers and 0 <= col_index < len(row):
                t_idx = self.headers.index(target)
                val = row[col_index]
                
                if t_idx >= len(row):
                    row.extend([''] * (t_idx - len(row) + 1))
                row[t_idx] = val
                
                # Strip the extra column if it sat outside the header bounds
                if col_index >= len(self.headers):
                    del row[col_index]

            self._resolve_by_padding(issue_index)
        return self._get_payload()

    def keep_unresolved(self, issue_index, col_index):
        self._save_state()
        self._resolve_by_padding(issue_index)
        return self._get_payload()

    def keep_issue_as_is(self, issue_index):
        self._save_state()
        # Real mutation: explicitly drop the issue from active list without mutating row
        self.issues = [i for i in self.issues if i['index'] != issue_index]
        return self._get_payload()

    def create_record_from_extras(self, issue_index, mapping_json):
        self._save_state()
        issue = next((i for i in self.issues if i['index'] == issue_index), None)
        if issue:
            r_idx = issue['row'] - 1
            row = self.rows[r_idx]
            expected_len = len(self.headers)
            
            try:
                mapping = json.loads(mapping_json)
            except Exception:
                mapping = {}
            
            new_row = [''] * expected_len
            
            # Real mutation: extract defined map or grab all trailing extras
            if mapping:
                for target_col, src_val in mapping.items():
                    if target_col in self.headers:
                        new_row[self.headers.index(target_col)] = str(src_val)
            elif len(row) > expected_len:
                extras = row[expected_len:]
                new_row = extras + [''] * max(0, expected_len - len(extras))
                new_row = new_row[:expected_len]

            # Track deterministic ID for deletion mapping
            record_id = self.record_counter
            self.record_counter += 1
            self.created_records[record_id] = new_row
            
            # Splice into dataset
            self.rows.insert(r_idx + 1, new_row)
            if len(self.rows[r_idx]) > expected_len:
                self.rows[r_idx] = self.rows[r_idx][:expected_len]
                
            self._recalculate_issues()
            
            # Append deterministic pseudo-issue to represent the creation
            self.issues.append({
                "index": record_id,
                "row": r_idx + 2,
                "type": "Created Record",
                "message": f"Created new record (ID: {record_id})"
            })
            
        return self._get_payload()

    def delete_created_record(self, record_id):
        self._save_state()
        try:
            r_id = int(record_id)
        except ValueError:
            return self._get_payload()
            
        target_row = self.created_records.get(r_id)
        if target_row:
            # Deterministic deletion by object identity mapping
            for idx, r in enumerate(self.rows):
                if r is target_row:
                    del self.rows[idx]
                    break
            del self.created_records[r_id]
            self.issues = [i for i in self.issues if i.get('index') != r_id]
            self._recalculate_issues()
            
        return self._get_payload()

    def undo_action(self):
        if self.history:
            # Real mutation: Restore exactly to previous arrays and mappings
            self.rows, self.issues, self.created_records = self.history.pop()
        return self._get_payload()

    def export_csv(self, dst):
        # Writes CURRENT mutated rows
        with open(dst, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(self.headers)
            writer.writerows(self.rows)

    def _resolve_by_padding(self, issue_index):
        issue = next((i for i in self.issues if i['index'] == issue_index), None)
        if issue:
            r_idx = issue['row'] - 1
            row = self.rows[r_idx]
            expected_len = len(self.headers)
            
            # Base structural mutation: pad or truncate row length
            if len(row) > expected_len:
                self.rows[r_idx] = row[:expected_len]
            elif len(row) < expected_len:
                self.rows[r_idx] = row + [''] * (expected_len - len(row))
            self._recalculate_issues()

    def _recalculate_issues(self):
        # Retain mapped created records explicitly outside of recalculation
        created_issues = [i for i in self.issues if i['type'] == 'Created Record']
        self.issues = []
        expected_len = len(self.headers)
        
        for i, row in enumerate(self.rows):
            if len(row) != expected_len:
                self.issues.append({
                    'index': len(self.issues),
                    'row': i + 1,
                    'type': 'Structural Mismatch',
                    'message': f'Expected {expected_len} columns, found {len(row)}.'
                })
                
        # Offset normal issues to avoid collision with record_counter
        for i, iss in enumerate(self.issues):
            iss['index'] = i
            
        for cr in created_issues:
            target_row = self.created_records.get(cr['index'])
            if target_row:
                for idx, r in enumerate(self.rows):
                    if r is target_row:
                        cr['row'] = idx + 1
                        self.issues.append(cr)
                        break

    def _get_payload(self):
        return {
            "headers": self.headers,
            "rows": self.rows,
            "issues": self.issues,
            "history": len(self.history)
        }
