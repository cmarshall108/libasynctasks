set_source_files_properties(${SOURCE_FILES} PROPERTIES CYTHON_IS_CXX FALSE)
cython_add_module(libasynctasks libasynctasks.pyx)
