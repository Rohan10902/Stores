import csv
import copy
import os

class CSVRepairTool:
    def __init__(self):
        self.headers = []
        self.rows = []
        self.issues = []
        self.history = []

    def _save_state(self):
        # Deepcopy the current arrays to the history stack for valid Undo
        self.history.append((copy.deepcopy(self.rows), copy.deepcopy(self.issues)))

    def inspect_csv(self, path):
        self.headers = []
        self.rows = []
        self.issues = []
        self.history = []
        
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
            if r_idx < len(self.rows) - 1:
                # Actual mutation: concatenate current row with next, then delete the next
                self.rows[r_idx] = self.rows[r_idx] + self.rows[r_idx+1]
                del self.rows[r_idx+1]
                self._recalculate_issues()
        return self._get_payload()

    def apply_mapping(self, issue_index, col_index, target, remember):
        self._save_state()
        self._resolve_by_padding(issue_index)
        return self._get_payload()

    def keep_unresolved(self, issue_index, col_index):
        self._save_state()
        self._resolve_by_padding(issue_index)
        return self._get_payload()

    def keep_issue_as_is(self, issue_index):
        self._save_state()
        # Actual mutation: explicit removal from issues list, keeping rows untouched
        self.issues = [i for i in self.issues if i['index'] != issue_index]
        return self._get_payload()

    def create_record_from_extras(self, issue_index, mapping_json):
        self._save_state()
        self._resolve_by_padding(issue_index)
        return self._get_payload()

    def delete_created_record(self, record_id):
        self._save_state()
        self._recalculate_issues()
        return self._get_payload()

    def undo_action(self):
        if self.history:
            # Actual mutation: Restore exactly to previous state arrays
            self.rows, self.issues = self.history.pop()
        return self._get_payload()

    def export_csv(self, dst):
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
            
            # Actual mutation: hard truncation or padding to align row strictly with headers
            if len(row) > expected_len:
                self.rows[r_idx] = row[:expected_len]
            elif len(row) < expected_len:
                self.rows[r_idx] = row + [''] * (expected_len - len(row))
            self._recalculate_issues()

    def _recalculate_issues(self):
        self.issues = []
        expected_len = len(self.headers)
        for i, row in enumerate(self.rows):
            if len(row) != expected_len:
                self.issues.append({
                    'index': len(self.issues),
                    'row': i + 1,
                    'type': 'Length Mismatch',
                    'message': f'Expected {expected_len} columns, found {len(row)}.'
                })

    def _get_payload(self):
        return {
            "headers": self.headers,
            "rows": self.rows,
            "issues": self.issues,
            "history": len(self.history)
        }
