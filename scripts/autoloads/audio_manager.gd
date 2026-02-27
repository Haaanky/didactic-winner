class_name AudioManager
extends Node

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"


func set_music_volume(volume_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_db)


func set_sfx_volume(volume_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(SFX_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_db)


func mute_music(muted: bool) -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, muted)


func mute_sfx(muted: bool) -> void:
	var bus_index := AudioServer.get_bus_index(SFX_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, muted)
