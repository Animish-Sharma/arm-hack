cmake_minimum_required(VERSION 3.22.1)
project("whisper_jni")

# whisper_jni: JNI glue that calls into libwhisper.so
add_library(whisper_jni SHARED whisper_jni.cpp)

# whisper.h is in the cpp/ folder alongside whisper_jni.cpp
target_include_directories(whisper_jni PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# Link against the pre-built libwhisper.so from jniLibs
add_library(whisper SHARED IMPORTED)
set_target_properties(whisper PROPERTIES
    IMPORTED_LOCATION
    ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libwhisper.so
)

target_link_libraries(whisper_jni
    whisper
    android
    log
)
