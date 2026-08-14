from PySide6.QtCore import QObject

from core.controllers import MainBackendController


def test_backend_controllers_are_real_qml_properties():
    backend = MainBackendController()

    for name in ("validate", "repair", "review", "creator", "health"):
        assert backend.metaObject().indexOfProperty(name) >= 0
        controller = getattr(backend, name)
        assert isinstance(controller, QObject)


def test_store_builder_controller_exposes_required_slots():
    creator = MainBackendController().creator

    assert callable(creator.load_creator_file)
    assert callable(creator.load_creator_text)
    assert callable(creator.validate_creator)
    assert callable(creator.export_builder_file)
