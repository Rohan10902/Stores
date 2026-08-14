from PySide6.QtCore import QObject

from core.controllers import MainBackendController


def test_backend_controllers_are_real_qml_properties():
    backend = MainBackendController()

    for name in ("validate", "repair", "review", "creator", "health"):
        assert backend.metaObject().indexOfProperty(name) >= 0
        controller = getattr(backend, name)
        assert isinstance(controller, QObject)


def test_store_builder_controller_exposes_required_slots():
    backend = MainBackendController()
    creator = backend.creator
    methods = {creator.metaObject().method(i).name().decode() for i in range(creator.metaObject().methodCount())}

    assert "load_creator_file" in methods
    assert "load_creator_text" in methods
    assert "validate_creator" in methods
    assert "export_builder_file" in methods
