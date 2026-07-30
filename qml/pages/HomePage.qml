// FIX: Limit paste to prevent massive DOM lockup
    function pasteText(t) {
        if (!t)
            return
        var lines = String(t).replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n")
        
        if (lines.length > 5000) {
            backend.say("Paste limit exceeded (5000 rows max). Please import large files directly.")
            return
        }
        
        if (lines.length && lines[lines.length - 1] === "")
            lines.pop()
        if (!lines.length)
            return

        var start = selectedRow
        for (var r = 0; r < lines.length; ++r) {
            var vals = lines[r].indexOf("\t") >= 0 ? lines[r].split("\t") : lines[r].split(",")
            var targetRow = start + r
            while (grid.count <= targetRow)
                addBlank(false)
            grid.setProperty(targetRow, "included", true)
            for (var c = 0; c < vals.length && selectedCol + c < headers.length; ++c)
                grid.setProperty(targetRow, "c" + (selectedCol + c), vals[c])
        }
        dirty = true
        backend.say("Pasted " + lines.length + " row(s). Extra rows were created automatically.")
    }

    // FIX: Hard cap the padding width to prevent memory exhaustion
    function padZeros(width) {
        var w = parseInt(width)
        if (!w || w < 1 || w > 100) {
            backend.say("Padding width must be between 1 and 100.")
            return
        }
        var cs = selectedColIndices()
        if (!cs.length)
            cs = [selectedCol]
        var changes = []
        var rs = effectiveRows()
        for (var i = 0; i < rs.length; ++i) {
            for (var j = 0; j < cs.length; ++j) {
                var c = cs[j]
                if (c !== 1 && c !== 3) {
                    backend.say("Zero padding is only available for SID and Nielsen Store Code.")
                    return
                }
                var before = String(grid.get(rs[i])["c" + c] || "").trim()
                if (!before || !/^\d+$/.test(before))
                    continue
                var after = before.length >= w ? before : before.padStart(w, "0")
                if (after !== before) {
                    changes.push({ row: rs[i], col: c, before: before })
                    grid.setProperty(rs[i], "c" + c, after)
                }
            }
        }
        if (changes.length) {
            pushUndo(changes, "Zero padding to width " + w)
            dirty = true
            lastBulkSummary = "Padded " + changes.length + " identifier(s) to width " + w + "."
            backend.say(lastBulkSummary)
        } else {
            backend.say("No numeric identifiers needed padding.")
        }
    }
