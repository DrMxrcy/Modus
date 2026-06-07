#!/usr/bin/env python3
"""Generate a clean EchoDJ.xcodeproj from scratch."""

import os
import uuid

SRC_DIR = '/Users/jp/Desktop/Dev/EchoDJ'
OUTPUT_PROJ = os.path.join(SRC_DIR, 'EchoDJ.xcodeproj')

def gen_uuid():
    return uuid.uuid4().hex.upper()[:24]

# Define all source files with their relative paths
SWIFT_FILES = [
    ('Core/EchoDJApp.swift', 'EchoDJApp.swift'),
    ('Core/AppEnvironment.swift', 'AppEnvironment.swift'),
    ('Data/Models/UserTasteProfile.swift', 'UserTasteProfile.swift'),
    ('Data/Models/TrackCooldown.swift', 'TrackCooldown.swift'),
    ('Data/Models/CachedTrack.swift', 'CachedTrack.swift'),
    ('Engine/Protocols/MusicProviderProtocol.swift', 'MusicProviderProtocol.swift'),
    ('Engine/Protocols/DJBrainProtocol.swift', 'DJBrainProtocol.swift'),
    ('Engine/Concrete/VectorAffinityEngine.swift', 'VectorAffinityEngine.swift'),
    ('Engine/Concrete/AppleMusicProvider.swift', 'AppleMusicProvider.swift'),
    ('Engine/Concrete/StationQueueManager.swift', 'StationQueueManager.swift'),
    ('Engine/Concrete/TelemetryCollector.swift', 'TelemetryCollector.swift'),
    ('Engine/Concrete/TTSClient.swift', 'TTSClient.swift'),
    ('Engine/Concrete/AudioDucker.swift', 'AudioDucker.swift'),
    ('Engine/Concrete/TransitionManager.swift', 'TransitionManager.swift'),
    ('Engine/Concrete/SubscriptionManager.swift', 'SubscriptionManager.swift'),
    ('Engine/Concrete/OnDeviceDJBrain.swift', 'OnDeviceDJBrain.swift'),
    ('Engine/Mocks/MockMusicProvider.swift', 'MockMusicProvider.swift'),
    ('Engine/Mocks/MockDJBrain.swift', 'MockDJBrain.swift'),
    ('UI/Tabs/MainTabView.swift', 'MainTabView.swift'),
    ('UI/Tabs/RadioView.swift', 'RadioView.swift'),
    ('UI/Tabs/SearchView.swift', 'SearchView.swift'),
    ('UI/Components/VibeVisualizer.swift', 'VibeVisualizer.swift'),
]

# Generate UUIDs
project_uuid = gen_uuid()
main_group_uuid = gen_uuid()
products_group_uuid = gen_uuid()
product_ref_uuid = gen_uuid()
target_uuid = gen_uuid()
sources_phase_uuid = gen_uuid()
frameworks_phase_uuid = gen_uuid()
musickit_ref_uuid = gen_uuid()
musickit_build_uuid = gen_uuid()
mediaplayer_ref_uuid = gen_uuid()
mediaplayer_build_uuid = gen_uuid()
avfoundation_ref_uuid = gen_uuid()
avfoundation_build_uuid = gen_uuid()
storekit_ref_uuid = gen_uuid()
storekit_build_uuid = gen_uuid()
resources_phase_uuid = gen_uuid()
project_config_list_uuid = gen_uuid()
target_config_list_uuid = gen_uuid()
debug_config_uuid = gen_uuid()
release_config_uuid = gen_uuid()
target_debug_config_uuid = gen_uuid()
target_release_config_uuid = gen_uuid()

# File references and build files
file_refs = {}
build_files = {}

for rel_path, name in SWIFT_FILES:
    file_uuid = gen_uuid()
    build_uuid = gen_uuid()
    file_refs[name] = {
        'uuid': file_uuid,
        'rel_path': rel_path,
        'name': name,
    }
    build_files[name] = {
        'uuid': build_uuid,
        'file_uuid': file_uuid,
        'name': name,
    }

# Info.plist
info_plist_uuid = gen_uuid()
info_build_uuid = gen_uuid()

# Assets (if we had them)
# assets_uuid = gen_uuid()
# assets_build_uuid = gen_uuid()

# Build the pbxproj content
lines = []
lines.append('// !$*UTF8*$!')
lines.append('{')
lines.append('\tarchiveVersion = 1;')
lines.append('\tclasses = {')
lines.append('\t};')
lines.append('\tobjectVersion = 56;')
lines.append('\tobjects = {')
lines.append('')

# PBXBuildFile section
lines.append('/* Begin PBXBuildFile section */')
for name, bf in build_files.items():
    lines.append(f"\t\t{bf['uuid']} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {bf['file_uuid']} /* {name} */; }};")
lines.append(f"\t\t{musickit_build_uuid} /* MusicKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {musickit_ref_uuid} /* MusicKit.framework */; }};")
lines.append(f"\t\t{mediaplayer_build_uuid} /* MediaPlayer.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {mediaplayer_ref_uuid} /* MediaPlayer.framework */; }};")
lines.append(f"\t\t{avfoundation_build_uuid} /* AVFoundation.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {avfoundation_ref_uuid} /* AVFoundation.framework */; }};")
lines.append(f"\t\t{storekit_build_uuid} /* StoreKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {storekit_ref_uuid} /* StoreKit.framework */; }};")
lines.append('/* End PBXBuildFile section */')
lines.append('')

# PBXFileReference section
lines.append('/* Begin PBXFileReference section */')
lines.append(f"\t\t{product_ref_uuid} /* EchoDJ.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = EchoDJ.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for name, fr in file_refs.items():
    lines.append(f"\t\t{fr['uuid']} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {fr['rel_path']}; sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{info_plist_uuid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = EchoDJ/Resources/Info.plist; sourceTree = SOURCE_ROOT; }};")
lines.append(f"\t\t{musickit_ref_uuid} /* MusicKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = MusicKit.framework; path = System/Library/Frameworks/MusicKit.framework; sourceTree = SDKROOT; }};")
lines.append(f"\t\t{mediaplayer_ref_uuid} /* MediaPlayer.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = MediaPlayer.framework; path = System/Library/Frameworks/MediaPlayer.framework; sourceTree = SDKROOT; }};")
lines.append(f"\t\t{avfoundation_ref_uuid} /* AVFoundation.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = AVFoundation.framework; path = System/Library/Frameworks/AVFoundation.framework; sourceTree = SDKROOT; }};")
lines.append(f"\t\t{storekit_ref_uuid} /* StoreKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = StoreKit.framework; path = System/Library/Frameworks/StoreKit.framework; sourceTree = SDKROOT; }};")
lines.append('/* End PBXFileReference section */')
lines.append('')

# PBXFrameworksBuildPhase section
lines.append('/* Begin PBXFrameworksBuildPhase section */')
lines.append(f"\t\t{frameworks_phase_uuid} /* Frameworks */ = {{")
lines.append('\t\t\tisa = PBXFrameworksBuildPhase;')
lines.append('\t\t\tbuildActionMask = 2147483647;')
lines.append('\t\t\tfiles = (')
lines.append(f"\t\t\t\t{musickit_build_uuid} /* MusicKit.framework in Frameworks */,")
lines.append(f"\t\t\t\t{mediaplayer_build_uuid} /* MediaPlayer.framework in Frameworks */,")
lines.append(f"\t\t\t\t{avfoundation_build_uuid} /* AVFoundation.framework in Frameworks */,")
lines.append(f"\t\t\t\t{storekit_build_uuid} /* StoreKit.framework in Frameworks */,")
lines.append('\t\t\t);')
lines.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append('\t\t};')
lines.append('/* End PBXFrameworksBuildPhase section */')
lines.append('')

# EchoDJ main group
echodj_group_uuid = gen_uuid()

# PBXGroup section
lines.append('/* Begin PBXGroup section */')
lines.append(f"\t\t{main_group_uuid} = {{")
lines.append('\t\t\tisa = PBXGroup;')
lines.append('\t\t\tchildren = (')
lines.append(f"\t\t\t\t{echodj_group_uuid} /* EchoDJ */,")
lines.append(f"\t\t\t\t{products_group_uuid} /* Products */,")
lines.append('\t\t\t);')
lines.append('\t\t\tsourceTree = "<group>";')
lines.append('\t\t};')

lines.append(f"\t\t{products_group_uuid} /* Products */ = {{")
lines.append('\t\t\tisa = PBXGroup;')
lines.append('\t\t\tchildren = (')
lines.append(f"\t\t\t\t{product_ref_uuid} /* EchoDJ.app */,")
lines.append('\t\t\t);')
lines.append('\t\t\tname = Products;')
lines.append('\t\t\tsourceTree = "<group>";')
lines.append('\t\t};')
lines.append(f"\t\t{echodj_group_uuid} /* EchoDJ */ = {{")
lines.append('\t\t\tisa = PBXGroup;')
lines.append('\t\t\tchildren = (')
for name, fr in file_refs.items():
    lines.append(f"\t\t\t\t{fr['uuid']} /* {name} */,")
lines.append(f"\t\t\t\t{info_plist_uuid} /* Info.plist */,")
lines.append('\t\t\t);')
lines.append('\t\t\tpath = EchoDJ;')
lines.append('\t\t\tsourceTree = "<group>";')
lines.append('\t\t};')

lines.append('/* End PBXGroup section */')
lines.append('')

# PBXNativeTarget section
lines.append('/* Begin PBXNativeTarget section */')
lines.append(f"\t\t{target_uuid} /* EchoDJ */ = {{")
lines.append('\t\t\tisa = PBXNativeTarget;')
lines.append(f"\t\t\tbuildConfigurationList = {target_config_list_uuid} /* Build configuration list for PBXNativeTarget \"EchoDJ\" */;")
lines.append('\t\t\tbuildPhases = (')
lines.append(f"\t\t\t\t{sources_phase_uuid} /* Sources */,")
lines.append(f"\t\t\t\t{frameworks_phase_uuid} /* Frameworks */,")
lines.append(f"\t\t\t\t{resources_phase_uuid} /* Resources */,")
lines.append('\t\t\t);')
lines.append('\t\t\tbuildRules = (')
lines.append('\t\t\t);')
lines.append('\t\t\tdependencies = (')
lines.append('\t\t\t);')
lines.append('\t\t\tname = EchoDJ;')
lines.append('\t\t\tproductName = EchoDJ;')
lines.append(f"\t\t\tproductReference = {product_ref_uuid} /* EchoDJ.app */;")
lines.append('\t\t\tproductType = "com.apple.product-type.application";')
lines.append('\t\t};')
lines.append('/* End PBXNativeTarget section */')
lines.append('')

# PBXProject section
lines.append('/* Begin PBXProject section */')
lines.append(f"\t\t{project_uuid} /* Project object */ = {{")
lines.append('\t\t\tisa = PBXProject;')
lines.append('\t\t\tattributes = {')
lines.append('\t\t\t\tBuildIndependentTargetsInParallel = 1;')
lines.append('\t\t\t\tLastSwiftUpdateCheck = 1600;')
lines.append('\t\t\t\tLastUpgradeCheck = 1600;')
lines.append('\t\t\t\tTargetAttributes = {')
lines.append(f"\t\t\t\t\t{target_uuid} = {{")
lines.append('\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;')
lines.append('\t\t\t\t\t};')
lines.append('\t\t\t\t};')
lines.append('\t\t\t};')
lines.append(f"\t\t\tbuildConfigurationList = {project_config_list_uuid} /* Build configuration list for PBXProject \"EchoDJ\" */;")
lines.append('\t\t\tcompatibilityVersion = "Xcode 14.0";')
lines.append('\t\t\tdevelopmentRegion = en;')
lines.append('\t\t\thasScannedForEncodings = 0;')
lines.append('\t\t\tknownRegions = (')
lines.append('\t\t\t\ten,')
lines.append('\t\t\t\tBase,')
lines.append('\t\t\t);')
lines.append(f"\t\t\tmainGroup = {main_group_uuid};")
lines.append(f"\t\t\tproductRefGroup = {products_group_uuid} /* Products */;")
lines.append('\t\t\tprojectDirPath = "";')
lines.append('\t\t\tprojectRoot = "";')
lines.append('\t\t\ttargets = (')
lines.append(f"\t\t\t\t{target_uuid} /* EchoDJ */,")
lines.append('\t\t\t);')
lines.append('\t\t};')
lines.append('/* End PBXProject section */')
lines.append('')

# PBXResourcesBuildPhase section
lines.append('/* Begin PBXResourcesBuildPhase section */')
lines.append(f"\t\t{resources_phase_uuid} /* Resources */ = {{")
lines.append('\t\t\tisa = PBXResourcesBuildPhase;')
lines.append('\t\t\tbuildActionMask = 2147483647;')
lines.append('\t\t\tfiles = (')
lines.append('\t\t\t);')
lines.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append('\t\t};')
lines.append('/* End PBXResourcesBuildPhase section */')
lines.append('')

# PBXSourcesBuildPhase section
lines.append('/* Begin PBXSourcesBuildPhase section */')
lines.append(f"\t\t{sources_phase_uuid} /* Sources */ = {{")
lines.append('\t\t\tisa = PBXSourcesBuildPhase;')
lines.append('\t\t\tbuildActionMask = 2147483647;')
lines.append('\t\t\tfiles = (')
for name, bf in build_files.items():
    lines.append(f"\t\t\t\t{bf['uuid']} /* {name} in Sources */,")
lines.append('\t\t\t);')
lines.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append('\t\t};')
lines.append('/* End PBXSourcesBuildPhase section */')
lines.append('')

# XCBuildConfiguration section
lines.append('/* Begin XCBuildConfiguration section */')
lines.append(f"\t\t{debug_config_uuid} /* Debug */ = {{")
lines.append('\t\t\tisa = XCBuildConfiguration;')
lines.append('\t\t\tbuildSettings = {')
lines.append('\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;')
lines.append('\t\t\t\tCLANG_ANALYZER_NONNULL = YES;')
lines.append('\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;')
lines.append('\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++17";')
lines.append('\t\t\t\tCLANG_ENABLE_MODULES = YES;')
lines.append('\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;')
lines.append('\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;')
lines.append('\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;')
lines.append('\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_COMMA = YES;')
lines.append('\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;')
lines.append('\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;')
lines.append('\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;')
lines.append('\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;')
lines.append('\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;')
lines.append('\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;')
lines.append('\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;')
lines.append('\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;')
lines.append('\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;')
lines.append('\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;')
lines.append('\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;')
lines.append('\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;')
lines.append('\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;')
lines.append('\t\t\t\tCOPY_PHASE_STRIP = NO;')
lines.append('\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;')
lines.append('\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;')
lines.append('\t\t\t\tENABLE_TESTABILITY = YES;')
lines.append('\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;')
lines.append('\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;')
lines.append('\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;')
lines.append('\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;')
lines.append('\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (')
lines.append('\t\t\t\t\t"DEBUG=1",')
lines.append('\t\t\t\t\t"$(inherited)",')
lines.append('\t\t\t\t);')
lines.append('\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;')
lines.append('\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;')
lines.append('\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;')
lines.append('\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;')
lines.append('\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;')
lines.append('\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;')
lines.append('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;')
lines.append('\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;')
lines.append('\t\t\t\tMTL_FAST_MATH = YES;')
lines.append('\t\t\t\tONLY_ACTIVE_ARCH = YES;')
lines.append('\t\t\t\tSDKROOT = iphoneos;')
lines.append('\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;')
lines.append('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";')
lines.append('\t\t\t};')
lines.append('\t\t\tname = Debug;')
lines.append('\t\t};')

lines.append(f"\t\t{release_config_uuid} /* Release */ = {{")
lines.append('\t\t\tisa = XCBuildConfiguration;')
lines.append('\t\t\tbuildSettings = {')
lines.append('\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;')
lines.append('\t\t\t\tCLANG_ANALYZER_NONNULL = YES;')
lines.append('\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;')
lines.append('\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++17";')
lines.append('\t\t\t\tCLANG_ENABLE_MODULES = YES;')
lines.append('\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;')
lines.append('\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;')
lines.append('\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;')
lines.append('\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_COMMA = YES;')
lines.append('\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;')
lines.append('\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;')
lines.append('\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;')
lines.append('\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;')
lines.append('\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;')
lines.append('\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;')
lines.append('\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;')
lines.append('\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;')
lines.append('\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;')
lines.append('\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;')
lines.append('\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;')
lines.append('\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;')
lines.append('\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;')
lines.append('\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;')
lines.append('\t\t\t\tCOPY_PHASE_STRIP = NO;')
lines.append('\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
lines.append('\t\t\t\tENABLE_NS_ASSERTIONS = NO;')
lines.append('\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;')
lines.append('\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;')
lines.append('\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;')
lines.append('\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;')
lines.append('\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;')
lines.append('\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;')
lines.append('\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;')
lines.append('\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;')
lines.append('\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;')
lines.append('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;')
lines.append('\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;')
lines.append('\t\t\t\tMTL_FAST_MATH = YES;')
lines.append('\t\t\t\tSDKROOT = iphoneos;')
lines.append('\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;')
lines.append('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";')
lines.append('\t\t\t\tVALIDATE_PRODUCT = YES;')
lines.append('\t\t\t};')
lines.append('\t\t\tname = Release;')
lines.append('\t\t};')

lines.append(f"\t\t{target_debug_config_uuid} /* Debug */ = {{")
lines.append('\t\t\tisa = XCBuildConfiguration;')
lines.append('\t\t\tbuildSettings = {')
lines.append('\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;')
lines.append('\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;')
lines.append('\t\t\t\tCODE_SIGN_STYLE = Automatic;')
lines.append('\t\t\t\tCURRENT_PROJECT_VERSION = 1;')
lines.append('\t\t\t\tENABLE_PREVIEWS = YES;')
lines.append('\t\t\t\tGENERATE_INFOPLIST_FILE = NO;')
lines.append('\t\t\t\tINFOPLIST_FILE = "EchoDJ/Resources/Info.plist";')
lines.append('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;')
lines.append('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (')
lines.append('\t\t\t\t\t"$(inherited)",')
lines.append('\t\t\t\t\t"@executable_path/Frameworks",')
lines.append('\t\t\t\t);')
lines.append('\t\t\t\tMARKETING_VERSION = 1.0;')
lines.append('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.echodj.app;')
lines.append('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
lines.append('\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;')
lines.append('\t\t\t\tSWIFT_STRICT_CONCURRENCY = complete;')
lines.append('\t\t\t\tSWIFT_VERSION = 6.0;')
lines.append('\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";')
lines.append('\t\t\t};')
lines.append('\t\t\tname = Debug;')
lines.append('\t\t};')

lines.append(f"\t\t{target_release_config_uuid} /* Release */ = {{")
lines.append('\t\t\tisa = XCBuildConfiguration;')
lines.append('\t\t\tbuildSettings = {')
lines.append('\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;')
lines.append('\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;')
lines.append('\t\t\t\tCODE_SIGN_STYLE = Automatic;')
lines.append('\t\t\t\tCURRENT_PROJECT_VERSION = 1;')
lines.append('\t\t\t\tENABLE_PREVIEWS = YES;')
lines.append('\t\t\t\tGENERATE_INFOPLIST_FILE = NO;')
lines.append('\t\t\t\tINFOPLIST_FILE = "EchoDJ/Resources/Info.plist";')
lines.append('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;')
lines.append('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (')
lines.append('\t\t\t\t\t"$(inherited)",')
lines.append('\t\t\t\t\t"@executable_path/Frameworks",')
lines.append('\t\t\t\t);')
lines.append('\t\t\t\tMARKETING_VERSION = 1.0;')
lines.append('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.echodj.app;')
lines.append('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
lines.append('\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;')
lines.append('\t\t\t\tSWIFT_STRICT_CONCURRENCY = complete;')
lines.append('\t\t\t\tSWIFT_VERSION = 6.0;')
lines.append('\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";')
lines.append('\t\t\t};')
lines.append('\t\t\tname = Release;')
lines.append('\t\t};')
lines.append('/* End XCBuildConfiguration section */')
lines.append('')

# XCConfigurationList section
lines.append('/* Begin XCConfigurationList section */')
lines.append(f"\t\t{project_config_list_uuid} /* Build configuration list for PBXProject \"EchoDJ\" */ = {{")
lines.append('\t\t\tisa = XCConfigurationList;')
lines.append('\t\t\tbuildConfigurations = (')
lines.append(f"\t\t\t\t{debug_config_uuid} /* Debug */,")
lines.append(f"\t\t\t\t{release_config_uuid} /* Release */,")
lines.append('\t\t\t);')
lines.append('\t\t\tdefaultConfigurationIsVisible = 0;')
lines.append('\t\t\tdefaultConfigurationName = Release;')
lines.append('\t\t};')

lines.append(f"\t\t{target_config_list_uuid} /* Build configuration list for PBXNativeTarget \"EchoDJ\" */ = {{")
lines.append('\t\t\tisa = XCConfigurationList;')
lines.append('\t\t\tbuildConfigurations = (')
lines.append(f"\t\t\t\t{target_debug_config_uuid} /* Debug */,")
lines.append(f"\t\t\t\t{target_release_config_uuid} /* Release */,")
lines.append('\t\t\t);')
lines.append('\t\t\tdefaultConfigurationIsVisible = 0;')
lines.append('\t\t\tdefaultConfigurationName = Release;')
lines.append('\t\t};')
lines.append('/* End XCConfigurationList section */')
lines.append('')

lines.append('\t};')
lines.append(f'\trootObject = {project_uuid} /* Project object */;')
lines.append('}')
lines.append('')

# Write the file
os.makedirs(OUTPUT_PROJ, exist_ok=True)
pbxproj_path = os.path.join(OUTPUT_PROJ, 'project.pbxproj')
with open(pbxproj_path, 'w') as f:
    f.write('\n'.join(lines))

# Create workspace file
workspace_dir = os.path.join(OUTPUT_PROJ, 'project.xcworkspace')
os.makedirs(workspace_dir, exist_ok=True)
with open(os.path.join(workspace_dir, 'contents.xcworkspacedata'), 'w') as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
    f.write('<Workspace version="1.0">\n')
    f.write('   <FileRef location="self:"></FileRef>\n')
    f.write('</Workspace>\n')

# Create IDEWorkspaceChecks.plist
os.makedirs(os.path.join(workspace_dir, 'xcshareddata'), exist_ok=True)
with open(os.path.join(workspace_dir, 'xcshareddata', 'IDEWorkspaceChecks.plist'), 'w') as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
    f.write('<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n')
    f.write('<plist version="1.0">\n')
    f.write('<dict>\n')
    f.write('   <key>IDEDidComputeMac32BitWarning</key>\n')
    f.write('   <true/>\n')
    f.write('</dict>\n')
    f.write('</plist>\n')

print(f"Generated {OUTPUT_PROJ}")
print(f"Open with: open {OUTPUT_PROJ}")
