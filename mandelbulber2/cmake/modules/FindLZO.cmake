find_path(LZO_INCLUDE_DIR NAMES lzo/lzo1x.h HINTS "${LZO_ROOT}/include")
find_library(LZO_LIBRARY NAMES lzo2 HINTS "${LZO_ROOT}/lib")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LZO REQUIRED_VARS LZO_LIBRARY LZO_INCLUDE_DIR)

if(LZO_FOUND AND NOT TARGET LZO::LZO)
    add_library(LZO::LZO UNKNOWN IMPORTED)
    set_target_properties(LZO::LZO PROPERTIES
        IMPORTED_LOCATION "${LZO_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${LZO_INCLUDE_DIR}")
endif()
mark_as_advanced(LZO_INCLUDE_DIR LZO_LIBRARY)
