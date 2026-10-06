extends SceneTree
func _initialize():
	var f=FileAccess.open("res://../THIRD_PARTY_NOTICES.txt",FileAccess.WRITE)
	f.store_string("Tideborn Island bundled runtime notices\n\n")
	f.store_string(Engine.get_license_text()+"\n\n")
	for info in Engine.get_copyright_info():
		f.store_string(str(info)+"\n\n")
	var licenses=Engine.get_license_info()
	for key in licenses: f.store_string(str(key)+"\n"+str(licenses[key])+"\n\n")
	f.close(); quit()
