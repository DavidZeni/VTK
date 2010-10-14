# Create custom commands to generate the python wrappers for this kit.
SET(TMP_WRAP_FILES ${Kit_SRCS} ${Kit_WRAP_HEADERS})
VTK_WRAP_PYTHON3(vtk${KIT}Python KitPython_SRCS "${TMP_WRAP_FILES}")

# Create a shared library containing the python wrappers.  Executables
# can link to this but it is not directly loaded dynamically as a
# module.
ADD_LIBRARY(vtk${KIT}PythonD ${KitPython_SRCS} ${Kit_PYTHON_EXTRA_SRCS})
TARGET_LINK_LIBRARIES(
  vtk${KIT}PythonD vtk${KIT} vtkPythonCore ${KIT_PYTHON_LIBS})
IF(NOT VTK_INSTALL_NO_LIBRARIES)
  INSTALL(TARGETS vtk${KIT}PythonD
    RUNTIME DESTINATION ${VTK_INSTALL_BIN_DIR_CM24} COMPONENT RuntimeLibraries
    LIBRARY DESTINATION ${VTK_INSTALL_LIB_DIR_CM24} COMPONENT RuntimeLibraries
    ARCHIVE DESTINATION ${VTK_INSTALL_LIB_DIR_CM24} COMPONENT Development)
ENDIF(NOT VTK_INSTALL_NO_LIBRARIES)
SET(KIT_LIBRARY_TARGETS ${KIT_LIBRARY_TARGETS} vtk${KIT}PythonD)

IF(VTK_WRAP_PYTHON_SIP)
  IF(NOT SIP_EXECUTABLE)
    MESSAGE(SEND_ERROR "SIP_EXECUTABLE not set.")
  ELSE(NOT SIP_EXECUTABLE)
    INCLUDE(${VTK_CMAKE_DIR}/vtkWrapPythonSIP.cmake)
    VTK_WRAP_PYTHON_SIP(${KIT} KitPythonSIP_SRCS "${Kit_SRCS}")
    INCLUDE_DIRECTORIES(${SIP_INCLUDE_DIR})
    ADD_LIBRARY(vtk${KIT}PythonSIP MODULE ${KitPythonSIP_SRCS})
    SET_TARGET_PROPERTIES(vtk${KIT}PythonSIP PROPERTIES PREFIX "" SKIP_BUILD_RPATH 1)
    IF(WIN32 AND NOT CYGWIN)
      SET_TARGET_PROPERTIES(vtk${KIT}PythonSIP PROPERTIES SUFFIX ".pyd")
    ENDIF(WIN32 AND NOT CYGWIN)
    TARGET_LINK_LIBRARIES(vtk${KIT}PythonSIP vtk${KIT}PythonD)
    IF(VTK_INSTALL_PYTHON_USING_CMAKE AND NOT VTK_INSTALL_NO_LIBRARIES)
      INSTALL(TARGETS vtk${KIT}PythonSIP
        RUNTIME DESTINATION ${VTK_INSTALL_BIN_DIR_CM24} COMPONENT RuntimeLibraries
        LIBRARY DESTINATION ${VTK_INSTALL_LIB_DIR_CM24} COMPONENT RuntimeLibraries
        ARCHIVE DESTINATION ${VTK_INSTALL_LIB_DIR_CM24} COMPONENT Development)
    ENDIF(VTK_INSTALL_PYTHON_USING_CMAKE AND NOT VTK_INSTALL_NO_LIBRARIES)
  ENDIF(NOT SIP_EXECUTABLE)
ENDIF(VTK_WRAP_PYTHON_SIP)


# Underlinking on purpose. The following library will not compile
# with LDFLAGS=-Wl,--no-undefined by design:
# On some UNIX platforms the python library is static and therefore
# should not be linked into the shared library.  Instead the symbols
# are exported from the python executable so that they can be used by
# shared libraries that are linked or loaded.  On Windows and OSX we
# want to link to the python libray to resolve its symbols
# immediately.
#IF(WIN32 OR APPLE)
#  TARGET_LINK_LIBRARIES (vtk${KIT}PythonD ${VTK_PYTHON_LIBRARIES})
#ENDIF(WIN32 OR APPLE)

# Add a top-level dependency on the main kit library.  This is needed
# to make sure no python source files are generated until the
# hierarchy file is built (it is built when the kit library builds)
ADD_DEPENDENCIES(vtk${KIT}PythonD vtk${KIT})

# Add dependencies that may have been generated by VTK_WRAP_PYTHON3 to
# the python wrapper library.  This is needed for the
# pre-custom-command hack in Visual Studio 6.
IF(KIT_PYTHON_DEPS)
  ADD_DEPENDENCIES(vtk${KIT}PythonD ${KIT_PYTHON_DEPS})
ENDIF(KIT_PYTHON_DEPS)

# Create a python module that can be loaded dynamically.  It links to
# the shared library containing the wrappers for this kit.
PYTHON_ADD_MODULE(vtk${KIT}Python vtk${KIT}PythonInit.cxx)
IF(PYTHON_ENABLE_MODULE_vtk${KIT}Python)
  TARGET_LINK_LIBRARIES(vtk${KIT}Python vtk${KIT}PythonD)
  
  # Python extension modules on Windows must have the extension ".pyd"
  # instead of ".dll" as of Python 2.5.  Older python versions do support
  # this suffix.
  IF(WIN32 AND NOT CYGWIN)
    SET_TARGET_PROPERTIES(vtk${KIT}Python PROPERTIES SUFFIX ".pyd")
  ENDIF(WIN32 AND NOT CYGWIN)

  # Make sure that no prefix is set on the library
  SET_TARGET_PROPERTIES(vtk${KIT}Python PROPERTIES PREFIX "")

  # Compatibility for projects that still expect the "lib" prefix
  IF(CYGWIN OR NOT WIN32)
    SET(suf ${CMAKE_SHARED_MODULE_SUFFIX})
    SET(src vtk${KIT}Python${suf})
    SET(tgt ${LIBRARY_OUTPUT_PATH}/libvtk${KIT}Python${suf})
    ADD_CUSTOM_COMMAND(TARGET vtk${KIT}Python POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E create_symlink ${src} ${tgt})
  ENDIF(CYGWIN OR NOT WIN32)

  # The python modules are installed by a setup.py script which does
  # not know how to adjust the RPATH field of the binary.  Therefore
  # we must simply build the modules with no RPATH at all.  The
  # vtkpython executable in the build tree should have the needed
  # RPATH anyway.
  SET_TARGET_PROPERTIES(vtk${KIT}Python PROPERTIES SKIP_BUILD_RPATH 1)
  
  IF(WIN32 OR APPLE)
    TARGET_LINK_LIBRARIES (vtk${KIT}Python ${VTK_PYTHON_LIBRARIES})
  ENDIF(WIN32 OR APPLE)

  # Generally the pyhon extension module created is installed using setup.py.
  # However projects that include VTK (such as ParaView) can override this
  # behaviour by not using setup.py, instead directly installing the extension
  # module at the same location as other libraries.
  IF (VTK_INSTALL_PYTHON_USING_CMAKE AND NOT VTK_INSTALL_NO_LIBRARIES)
    INSTALL(TARGETS vtk${KIT}Python
      RUNTIME DESTINATION ${VTK_INSTALL_BIN_DIR_CM24} COMPONENT RuntimeLibraries
      LIBRARY DESTINATION ${VTK_INSTALL_LIB_DIR_CM24} COMPONENT RuntimeLibraries
      ARCHIVE DESTINATION ${VTK_INSTALL_LIB_DIR_CM24} COMPONENT Development)
  ENDIF (VTK_INSTALL_PYTHON_USING_CMAKE AND NOT VTK_INSTALL_NO_LIBRARIES)
ENDIF(PYTHON_ENABLE_MODULE_vtk${KIT}Python)
