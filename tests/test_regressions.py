import csv, tempfile, unittest
from pathlib import Path
import pandas as pd
from core.common import read_table, map_columns, date_ok, binary_ok
from core.explorer import prepare_for_sql
from core.file_creator import review_dataframe, creator_validate
from core.csv_repair import inspect_csv, apply_mapping, undo_last_created_action, keep_issue_as_is, unresolved_extras, save_repaired
from core.quality import profile_dataframe

class RegressionTests(unittest.TestCase):
    def test_multiline_csv_and_duplicate_headers(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"x.csv";p.write_text('SID,Notes,Notes\n001,"hello\nworld",x\n',encoding='utf-8-sig');df=read_table(p);self.assertEqual(len(df),1);self.assertEqual(list(df.columns),['SID','Notes','Notes (2)']);self.assertEqual(df.iloc[0]['Notes'],'hello\nworld')
    def test_identifier_columns_remain_text_for_sql(self):
        df=pd.DataFrame({'SID':['001','002'],'ZIP':['041100','041101'],'Amount':['1','2']});typed,schema=prepare_for_sql(df);self.assertEqual(schema['SID'],'VARCHAR');self.assertEqual(schema['ZIP'],'VARCHAR');self.assertEqual(typed['SID'].iloc[0],'001');self.assertEqual(schema['Amount'],'BIGINT')
    def test_review_requires_identity_and_uses_dominant_nielsen_width(self):
        df=pd.DataFrame({'SID':['','2','3'],'Store Name':['A','B','C'],'Nielsen Store Code':['0001','0002','999999']});report=review_dataframe(df);self.assertEqual(report['suggestedNielsenWidth'],4);self.assertGreaterEqual(report['issueCount'],2);self.assertGreaterEqual(report['findingCount'],2)
    def test_builder_requires_sid_and_store_name(self):
        findings=creator_validate([{'Banner':'X'}]);fields={x['field'] for x in findings};self.assertIn('SID',fields);self.assertIn('Store Name',fields)
    def test_builder_requires_zero_one_boolean_values(self):
        row={'Store Name':'A','SID':'001','Active / Inactive':'1','Is Census':'1','Is Exceptions':'0','Trip Received':'2026-07-01','Last Trip':'2026-07-02'}
        self.assertEqual(creator_validate([row]),[])
        row['Active / Inactive']='0';row['Is Census']='0';row['Is Exceptions']='1'
        self.assertEqual(creator_validate([row]),[])
        for value in ('Active','Inactive','Yes','No','true','false','True','False','1.0','2'):
            self.assertFalse(binary_ok(value), value)
    def test_builder_handles_100_valid_records_without_findings(self):
        rows=[]
        for i in range(100):
            n=i+1
            rows.append({'Store Name':f'Store {n:03d}','SID':f'{100000+n}','Banner':'Test Banner','Nielsen Store Code':f'{100000000+n}','Trip Received':'2026-07-01','Last Trip':'2026-07-02','Address 1':f'{n} Main Street','ZIP':f'{10000+n:05d}','Active / Inactive':'1','Is Census':'1' if n % 2 else '0','Is Exceptions':'0','Updated By':'Test'})
        self.assertEqual(creator_validate(rows),[])
    def test_absorb_only_empty_and_undo(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'x.csv';p.write_text('SID,Store Name,ZIP\n1,,411004,City Bazaar\n',encoding='utf-8');audit=inspect_csv(p);self.assertEqual(len(audit['issues']),1);apply_mapping(audit,0,3,'Store Name');self.assertEqual(audit['logical'][1]['values'][1],'City Bazaar');undo_last_created_action(audit);self.assertEqual(audit['logical'][1]['values'][1],'')
    def test_keep_unresolved_is_exportable_without_overflow_columns(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'x.csv';out=Path(d)/'out.csv';p.write_text('SID,Store Name\n1,A,EXTRA\n',encoding='utf-8');audit=inspect_csv(p);keep_issue_as_is(audit,0);self.assertEqual(unresolved_extras(audit),[]);save_repaired(audit,out);rows=list(csv.reader(out.read_text(encoding='utf-8-sig').splitlines()));self.assertTrue(all(len(r)==2 for r in rows));self.assertNotIn('EXTRA',out.read_text(encoding='utf-8-sig'))
    def test_column_mapping_prefers_exact_names(self):
        mapping=map_columns(['Store Name','Store ID','Postal Code','Random']);self.assertEqual(mapping['Store Name']['column'],'Store Name');self.assertEqual(mapping['ZIP']['column'],'Postal Code')
    def test_empty_date_and_boolean_values_are_allowed(self):
        self.assertTrue(date_ok(''));self.assertTrue(binary_ok(''));self.assertTrue(binary_ok('0'));self.assertTrue(binary_ok('1'))
    def test_invalid_date_and_boolean_values_are_rejected(self):
        self.assertFalse(date_ok('not-a-date'))
        for value in ('maybe','yes','no','true','false','Active','Inactive','2','1.0'):
            self.assertFalse(binary_ok(value), value)
    def test_short_csv_rows_are_padded_without_losing_records(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'short.csv';p.write_text('SID,Store Name,ZIP\n1,A\n2,B,411004\n',encoding='utf-8');df=read_table(p);self.assertEqual(len(df),2);self.assertEqual(df.iloc[0]['ZIP'],'')
    def test_quality_profile_is_explainable_and_non_mutating(self):
        df=pd.DataFrame({'SID':['001','002','002'],'Name':['A','B','C']});before=df.copy(deep=True);profile=profile_dataframe(df);self.assertEqual(profile['rows'],3);self.assertEqual(profile['columns'],2);self.assertEqual(profile['missingCells'],0);self.assertEqual(profile['duplicateRows'],0);self.assertIn(profile['grade'],{'Excellent','Good','Needs attention','Poor'});self.assertEqual(profile['dimensions'][0]['name'],'Completeness');pd.testing.assert_frame_equal(df,before)
    def test_quality_profile_empty_frame_is_safe(self):
        profile=profile_dataframe(pd.DataFrame());self.assertEqual(profile['rows'],0);self.assertEqual(profile['columns'],0);self.assertEqual(profile['score'],100.0);self.assertEqual(profile['grade'],'Excellent')

if __name__=='__main__':unittest.main()
