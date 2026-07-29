@@
 class Backend(QObject):
@@
     creatorReady = Signal(str)
+    creatorLoaded = Signal(str)
@@
     def exportCreator(self, rows_json, dst):
@@
         except Exception as e:
             self.fail(e)
+
+    @Slot(str)
+    def loadCreatorFile(self, path):
+        try:
+            local = self._local(path)
+            df = read_table(local)
+            # Build header list and row objects
+            headers = [str(c) for c in df.columns]
+            rows = []
+            for row in df.itertuples(index=False, name=None):
+                obj = {}
+                for i, v in enumerate(row):
+                    obj[headers[i]] = json_value(v)
+                rows.append(obj)
+            payload = json.dumps({"headers": headers, "rows": rows}, default=str)
+            self.creatorLoaded.emit(payload)
+            self.say(f"Imported {len(rows):,} row(s) from file")
+        except Exception as e:
+            self.fail(e)
@@
 def main():
@@
     engine.load(QUrl.fromLocalFile(str(BASE / "qml" / "Main.qml")))
@@
 if __name__ == "__main__":
     sys.exit(main())
