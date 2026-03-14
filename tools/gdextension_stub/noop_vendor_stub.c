#include "gdextension_interface.h"

#if defined(_WIN32)
#define STUB_EXPORT __declspec(dllexport)
#else
#define STUB_EXPORT __attribute__((visibility("default")))
#endif

static void noop_initialize(void *p_userdata, GDExtensionInitializationLevel p_level) {
	(void)p_userdata;
	(void)p_level;
}

static void noop_deinitialize(void *p_userdata, GDExtensionInitializationLevel p_level) {
	(void)p_userdata;
	(void)p_level;
}

STUB_EXPORT GDExtensionBool plugin_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	(void)p_get_proc_address;
	(void)p_library;
	if (r_initialization == NULL) {
		return 0;
	}

	r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_CORE;
	r_initialization->userdata = NULL;
	r_initialization->initialize = noop_initialize;
	r_initialization->deinitialize = noop_deinitialize;
	return 1;
}
