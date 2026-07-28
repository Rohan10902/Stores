import tempfile, unittest
from pathlib import Path
import pandas as pd
from core.common import read_table, map_columns, date_ok, binary_ok
from core.explorer import prepare_for_sql
from core.file_creator import review_dataframe, creator_validate
from core.csv_repair import inspect_csv, apply_mapping, undo_last_created_action, keep_issue_as_is, unresolved_extras, save_repaired

class RegressionTests(unittest.TestCase):
    def test_multiline_csv_and_duplicate_headers(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"x.csv";p.write_text('SID,Notes,Notes\n001,"hello\nworld",x\n',encoding='utf-8')
            df=read_table(p);self.assertEqual(len(df),1);self.assertEqual(list(df.columns),['SID','Notes','Notes (2)']);self.assertEqual(df.iloc[0]['Notes'],'hello\nworld')

    def test_identifier_columns_remain_text_for_sql(self):
        df=pd.DataFrame({'SID':['001','002'],'ZIP':['041100','041101'],'Amount':['1','2']});typed,schema=prepare_for_sql(df)
        self.assertEqual(schema['SID'],'VARCHAR');self.assertEqual(schema['ZIP'],'VARCHAR');self.assertEqual(typed['SID'].iloc[0],'001');self.assertEqual(schema['Amount'],'BIGINT')

    def test_review_requires_identity_and_uses_dominant_nielsen_width(self):
        df=pd.DataFrame({'SID':['','2','3'],'Store Name':['A','B','C'],'Nielsen Store Code':['0001','0002','999999']})
        report=review_dataframe(df);self.assertEqual(report['suggestedNielsenWidth'],4);self.assertGreaterEqual(report['issueCount'],2);self.assertGreaterEqual(report['findingCount'],2)

    def test_builder_requires_sid_and_store_name(self):
        findings=creator_validate([{'Banner':'X'}]);fields={x['field'] for x in findings};self.assertIn('SID',fields);self.assertIn('Store Name',fields)

    def test_absorb_only_empty_and_undo(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'x.csv';p.write_text('SID,Store Name,ZIP\n1,,411004\n',encoding='utf-8');audit=inspect_csv(p);self.assertEqual(len(audit['issues']),1);apply_mapping(audit,0,3,'Store Name');self.assertEqual(audit['logical'][1]['values'][1],'411004');undo_last_created_action(audit);self.assertEqual(audit['logical'][1]['values'][1],'')

    def test_keep_unresolved_is_exportable_and_preserved(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'x.csv';out=Path(d)/'out.csv';p.write_text('SID,Store Name\n1,A,EXTRA\n',encoding='utf-8');audit=inspect_csv(p);keep_issue_as_is(audit,0);save_repaired(audit,out);self.assertIn('EXTRA',out.read_text(encoding='utf-8-sig'))

    def test_column_mapping_prefers_exact_names(self):
        mapping=map_columns(['Store Name','Store ID','Postal Code','Random'])
        self.assertEqual(mapping['Store Name']['column'],'Store Name')
        self.assertEqual(mapping['ZIP']['column'],'Postal Code')

    def test_empty_date_and_boolean_values_are_allowed(self):
        self.assertTrue(date_ok(''));self.assertTrue(binary_ok(''));self.assertTrue(binary_ok('yes'));self.assertTrue(binary_ok('0'))

    def test_invalid_date_and_boolean_values_are_rejected(self):
        self.assertFalse(date_ok('not-a-date'));self.assertFalse(binary_ok('maybe'))

    def test_short_csv_rows_are_padded_without_losing_records(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'short.csv';p.write_text('SID,Store Name,ZIP\n1,A\n2,B,411004\n',encoding='utf-8');df=read_table(p)
            self.assertEqual(len(df),2);self.assertEqual(df.iloc[0]['ZIP'],'')

if __name__=='__main__':unittest.main()
