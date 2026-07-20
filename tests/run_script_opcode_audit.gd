extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("FAIL: 无法加载本地 DOS 数据：%s" % database.error_message)
		quit(1)
		return
	var report := PalScriptAudit.audit(database)
	var labels := PalScriptAudit.unsupported_labels(report)
	var used_count := int(report.used_operations.size())
	if used_count != 164 or not labels.is_empty():
		var missing_kinds: Dictionary = {}
		for issue in report.unsupported:
			missing_kinds["%s:%04X" % [PalScriptAudit.CONTEXT_NAMES[int(issue.context)], int(issue.operation)]] = true
		printerr("FAIL: 实际使用 %d/164；上下文缺口 %d 个入口 / %d 类：%s" % [used_count, labels.size(), missing_kinds.size(), ", ".join(missing_kinds.keys())])
		for context in range(PalScriptAudit.CONTEXT_NAMES.size()):
			var context_report: Dictionary = report.contexts[context]
			print("%s roots=%d opcodes=%d" % [PalScriptAudit.CONTEXT_NAMES[context], context_report.roots.size(), context_report.operations.size()])
		quit(1)
		return
	print("PASS: DOS 实际使用的 164 种操作码在主触发/自动/即时/装备/战斗效果/敌人战斗六类真实上下文中全部支持")
	quit()
