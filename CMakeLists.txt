cmake_minimum_required(VERSION 3.23)
project(CMock C)

set(CMAKE_C_STANDARD 99)

add_library(cmock src/cmock.c vendor/unity/src/unity.c)
target_include_directories(cmock PRIVATE vendor/unity/src/)
target_sources(cmock INTERFACE FILE_SET HEADERS BASE_DIRS src/ vendor/unity/src FILES src/cmock.h vendor/unity/src/unity.h)

include(GNUInstallDirs)

file(GLOB INSTALLABLE_HEADERS src/*.h vendor/unity/src/*.h)


install(TARGETS cmock)

install(FILES ${INSTALLABLE_HEADERS}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

install(FILES LICENSE.txt
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/cmock)

install(DIRECTORY docs/ examples
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/cmock/docs/)

install(DIRECTORY lib/
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/cmock/lib/)

install(FILES README.md
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/cmock/docs/)

install(DIRECTORY vendor/unity/docs/ vendor/unity/examples
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/unity/docs)

install(DIRECTORY vendor/unity/auto/
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/unity/auto)

install(FILES vendor/unity/LICENSE.txt
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/unity/)

install(FILES vendor/unity/README.md
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/unity/docs)

set(CPACK_PACKAGE_NAME "CMock")
set(CPACK_PACKAGE_VENDOR "Mark Moss")
set(CPACK_PACKAGE_VERSION_MAJOR "2023")
set(CPACK_PACKAGE_VERSION_MINOR "10")
set(CPACK_PACKAGE_VERSION_PATCH "250")
set(CPACK_GENERATOR "ZIP;TGZ;NSIS;NSIS64")
set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
include(CPack)