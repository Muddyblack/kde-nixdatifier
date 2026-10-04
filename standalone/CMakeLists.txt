cmake_minimum_required(VERSION 3.20)

# One version for every host: the Plasma package metadata.
get_filename_component(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
file(READ "${REPO_ROOT}/package/metadata.json" NIXDATIFIER_METADATA)
string(JSON NIXDATIFIER_VERSION GET "${NIXDATIFIER_METADATA}" KPlugin Version)

project(nixdatifier VERSION ${NIXDATIFIER_VERSION} LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Widgets Svg Qml Quick QuickControls2 Network)

# The tray artwork renderer is shared with the Quickshell tray helper.
qt_add_executable(nixdatifier
    main.cpp
    Host.cpp
    ProcessRunner.cpp
    ${REPO_ROOT}/tray/TrayIconRenderer.cpp)
target_include_directories(nixdatifier PRIVATE ${REPO_ROOT}/tray)
target_compile_definitions(nixdatifier PRIVATE NIXDATIFIER_VERSION="${NIXDATIFIER_VERSION}")
target_link_libraries(nixdatifier PRIVATE
    Qt6::Widgets Qt6::Svg Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network)

# The QML UI and its shell helpers stay plain files on disk: the Engine locates
# its scripts relative to its own URL, exactly as in the Plasma package.
include(GNUInstallDirs)
install(TARGETS nixdatifier RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY ${REPO_ROOT}/package/ DESTINATION share/nixdatifier/package
    USE_SOURCE_PERMISSIONS
    PATTERN "*.plasmoid" EXCLUDE
    PATTERN "icon-emblem.png" EXCLUDE)
install(FILES Main.qml DESTINATION share/nixdatifier/standalone)
install(FILES nixdatifier.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES ${REPO_ROOT}/package/icon.png
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps
    RENAME nixdatifier.png)
