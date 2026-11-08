#!/usr/bin/env python3
import os
import sys
import uuid

def generate_uuid():
    return uuid.uuid4().hex[:24].upper()

def main():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    noty_dir = os.path.join(base_dir, "Noty")
    tests_dir = os.path.join(base_dir, "NotyTests")
    proj_dir = os.path.join(base_dir, "Noty.xcodeproj")
    schemes_dir = os.path.join(proj_dir, "xcshareddata", "xcschemes")
    os.makedirs(schemes_dir, exist_ok=True)

    # Collect source files
    noty_sources = []
    for root, dirs, files in os.walk(noty_dir):
        for f in files:
            if f.endswith(".swift"):
                rel = os.path.relpath(os.path.join(root, f), base_dir)
                noty_sources.append(rel)

    test_sources = []
    for root, dirs, files in os.walk(tests_dir):
        for f in files:
            if f.endswith(".swift"):
                rel = os.path.relpath(os.path.join(root, f), base_dir)
                test_sources.append(rel)

    # Identifiers
    id_project = generate_uuid()
    id_main_group = generate_uuid()
    id_products_group = generate_uuid()
    
    id_app_target = generate_uuid()
    id_app_product = generate_uuid()
    id_app_sources_build_phase = generate_uuid()
    id_app_frameworks_build_phase = generate_uuid()
    id_app_resources_build_phase = generate_uuid()
    id_app_config_list = generate_uuid()
    id_app_debug_config = generate_uuid()
    id_app_release_config = generate_uuid()

    id_test_target = generate_uuid()
    id_test_product = generate_uuid()
    id_test_sources_build_phase = generate_uuid()
    id_test_frameworks_build_phase = generate_uuid()
    id_test_resources_build_phase = generate_uuid()
    id_test_config_list = generate_uuid()
    id_test_debug_config = generate_uuid()
    id_test_release_config = generate_uuid()
    id_target_dependency = generate_uuid()
    id_container_item_proxy = generate_uuid()

    id_proj_config_list = generate_uuid()
    id_proj_debug_config = generate_uuid()
    id_proj_release_config = generate_uuid()

    # File references and build files
    file_refs = {}
    build_files = {}

    for src in noty_sources:
        f_id = generate_uuid()
        b_id = generate_uuid()
        file_refs[src] = (f_id, b_id, "sourcecode.swift")
        build_files[b_id] = (f_id, os.path.basename(src), "Sources")

    for src in test_sources:
        f_id = generate_uuid()
        b_id = generate_uuid()
        file_refs[src] = (f_id, b_id, "sourcecode.swift")
        build_files[b_id] = (f_id, os.path.basename(src), "Sources")

    # Assets & Plists
    assets_rel = "Noty/Resources/Assets.xcassets"
    assets_f_id = generate_uuid()
    assets_b_id = generate_uuid()
    file_refs[assets_rel] = (assets_f_id, assets_b_id, "folder.assetcatalog")
    build_files[assets_b_id] = (assets_f_id, "Assets.xcassets", "Resources")

    entitlements_rel = "Noty/Resources/Noty.entitlements"
    entitlements_f_id = generate_uuid()
    file_refs[entitlements_rel] = (entitlements_f_id, None, "text.plist.entitlements")

    info_plist_rel = "Noty/Resources/Info.plist"
    info_plist_f_id = generate_uuid()
    file_refs[info_plist_rel] = (info_plist_f_id, None, "text.plist.xml")

    # Construct PBX
    pbx = []
    pbx.append("// !$*UTF8*$!")
    pbx.append("{")
    pbx.append("\tarchiveVersion = 1;")
    pbx.append("\tclasses = {")
    pbx.append("\t};")
    pbx.append("\tobjectVersion = 56;")
    pbx.append("\tobjects = {")

    # PBXBuildFile
    pbx.append("\n/* Begin PBXBuildFile section */")
    for b_id, (f_id, name, phase) in build_files.items():
        pbx.append(f"\t\t{b_id} /* {name} in {phase} */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {name} */; }};")
    pbx.append("/* End PBXBuildFile section */")

    # PBXContainerItemProxy
    pbx.append("\n/* Begin PBXContainerItemProxy section */")
    pbx.append(f"\t\t{id_container_item_proxy} /* PBXContainerItemProxy */ = {{")
    pbx.append("\t\t\tisa = PBXContainerItemProxy;")
    pbx.append(f"\t\t\tcontainerPortal = {id_project} /* Project object */;")
    pbx.append("\t\t\tproxyType = 1;")
    pbx.append(f"\t\t\tremoteGlobalIDString = {id_app_target};")
    pbx.append("\t\t\tremoteInfo = Noty;")
    pbx.append("\t\t};")
    pbx.append("/* End PBXContainerItemProxy section */")

    # PBXFileReference
    pbx.append("\n/* Begin PBXFileReference section */")
    pbx.append(f"\t\t{id_app_product} /* Noty.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Noty.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    pbx.append(f"\t\t{id_test_product} /* NotyTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = NotyTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for rel, (f_id, b_id, f_type) in file_refs.items():
        name = os.path.basename(rel)
        pbx.append(f"\t\t{f_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {f_type}; path = \"{rel}\"; sourceTree = \"<group>\"; }};")
    pbx.append("/* End PBXFileReference section */")

    # PBXFrameworksBuildPhase
    pbx.append("\n/* Begin PBXFrameworksBuildPhase section */")
    pbx.append(f"\t\t{id_app_frameworks_build_phase} /* Frameworks */ = {{")
    pbx.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    pbx.append(f"\t\t{id_test_frameworks_build_phase} /* Frameworks */ = {{")
    pbx.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    pbx.append("/* End PBXFrameworksBuildPhase section */")

    # PBXGroup
    pbx.append("\n/* Begin PBXGroup section */")
    # Main group
    pbx.append(f"\t\t{id_main_group} = {{")
    pbx.append("\t\t\tisa = PBXGroup;")
    pbx.append("\t\t\tchildren = (")
    for rel, (f_id, b_id, f_type) in sorted(file_refs.items()):
        name = os.path.basename(rel)
        pbx.append(f"\t\t\t\t{f_id} /* {name} */,")
    pbx.append(f"\t\t\t\t{id_products_group} /* Products */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tsourceTree = \"<group>\";")
    pbx.append("\t\t};")

    # Products group
    pbx.append(f"\t\t{id_products_group} /* Products */ = {{")
    pbx.append("\t\t\tisa = PBXGroup;")
    pbx.append("\t\t\tchildren = (")
    pbx.append(f"\t\t\t\t{id_app_product} /* Noty.app */,")
    pbx.append(f"\t\t\t\t{id_test_product} /* NotyTests.xctest */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tname = Products;")
    pbx.append("\t\t\tsourceTree = \"<group>\";")
    pbx.append("\t\t};")
    pbx.append("/* End PBXGroup section */")

    # PBXNativeTarget
    pbx.append("\n/* Begin PBXNativeTarget section */")
    # App target
    pbx.append(f"\t\t{id_app_target} /* Noty */ = {{")
    pbx.append("\t\t\tisa = PBXNativeTarget;")
    pbx.append(f"\t\t\tbuildConfigurationList = {id_app_config_list} /* Build configuration list for PBXNativeTarget \"Noty\" */;")
    pbx.append("\t\t\tbuildPhases = (")
    pbx.append(f"\t\t\t\t{id_app_sources_build_phase} /* Sources */,")
    pbx.append(f"\t\t\t\t{id_app_frameworks_build_phase} /* Frameworks */,")
    pbx.append(f"\t\t\t\t{id_app_resources_build_phase} /* Resources */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tbuildRules = (")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdependencies = (")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tname = Noty;")
    pbx.append("\t\t\tproductName = Noty;")
    pbx.append(f"\t\t\tproductReference = {id_app_product} /* Noty.app */;")
    pbx.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    pbx.append("\t\t};")

    # Test target
    pbx.append(f"\t\t{id_test_target} /* NotyTests */ = {{")
    pbx.append("\t\t\tisa = PBXNativeTarget;")
    pbx.append(f"\t\t\tbuildConfigurationList = {id_test_config_list} /* Build configuration list for PBXNativeTarget \"NotyTests\" */;")
    pbx.append("\t\t\tbuildPhases = (")
    pbx.append(f"\t\t\t\t{id_test_sources_build_phase} /* Sources */,")
    pbx.append(f"\t\t\t\t{id_test_frameworks_build_phase} /* Frameworks */,")
    pbx.append(f"\t\t\t\t{id_test_resources_build_phase} /* Resources */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tbuildRules = (")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdependencies = (")
    pbx.append(f"\t\t\t\t{id_target_dependency} /* PBXTargetDependency */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tname = NotyTests;")
    pbx.append("\t\t\tproductName = NotyTests;")
    pbx.append(f"\t\t\tproductReference = {id_test_product} /* NotyTests.xctest */;")
    pbx.append("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    pbx.append("\t\t};")
    pbx.append("/* End PBXNativeTarget section */")

    # PBXProject
    pbx.append("\n/* Begin PBXProject section */")
    pbx.append(f"\t\t{id_project} /* Project object */ = {{")
    pbx.append("\t\t\tisa = PBXProject;")
    pbx.append("\t\t\tattributes = {")
    pbx.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    pbx.append("\t\t\t\tLastUpgradeCheck = 1600;")
    pbx.append("\t\t\t\tTargetAttributes = {")
    pbx.append(f"\t\t\t\t\t{id_app_target} = {{")
    pbx.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    pbx.append("\t\t\t\t\t};")
    pbx.append(f"\t\t\t\t\t{id_test_target} = {{")
    pbx.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    pbx.append(f"\t\t\t\t\t\tTestTargetID = {id_app_target};")
    pbx.append("\t\t\t\t\t};")
    pbx.append("\t\t\t\t};")
    pbx.append("\t\t\t};")
    pbx.append(f"\t\t\tbuildConfigurationList = {id_proj_config_list} /* Build configuration list for PBXProject \"Noty\" */;")
    pbx.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    pbx.append("\t\t\tdevelopmentRegion = en;")
    pbx.append("\t\t\thasScannedForEncodings = 0;")
    pbx.append("\t\t\tknownRegions = (")
    pbx.append("\t\t\t\ten,")
    pbx.append("\t\t\t\tBase,")
    pbx.append("\t\t\t);")
    pbx.append(f"\t\t\tmainGroup = {id_main_group};")
    pbx.append(f"\t\t\tproductRefGroup = {id_products_group} /* Products */;")
    pbx.append("\t\t\tprojectDirPath = \"\";")
    pbx.append("\t\t\tprojectRoot = \"\";")
    pbx.append("\t\t\ttargets = (")
    pbx.append(f"\t\t\t\t{id_app_target} /* Noty */,")
    pbx.append(f"\t\t\t\t{id_test_target} /* NotyTests */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t};")
    pbx.append("/* End PBXProject section */")

    # PBXResourcesBuildPhase
    pbx.append("\n/* Begin PBXResourcesBuildPhase section */")
    pbx.append(f"\t\t{id_app_resources_build_phase} /* Resources */ = {{")
    pbx.append("\t\t\tisa = PBXResourcesBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    pbx.append(f"\t\t\t\t{assets_b_id} /* Assets.xcassets in Resources */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    pbx.append(f"\t\t{id_test_resources_build_phase} /* Resources */ = {{")
    pbx.append("\t\t\tisa = PBXResourcesBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    pbx.append("/* End PBXResourcesBuildPhase section */")

    # PBXSourcesBuildPhase
    pbx.append("\n/* Begin PBXSourcesBuildPhase section */")
    pbx.append(f"\t\t{id_app_sources_build_phase} /* Sources */ = {{")
    pbx.append("\t\t\tisa = PBXSourcesBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    for src in noty_sources:
        _, b_id, _ = file_refs[src]
        name = os.path.basename(src)
        pbx.append(f"\t\t\t\t{b_id} /* {name} in Sources */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")

    pbx.append(f"\t\t{id_test_sources_build_phase} /* Sources */ = {{")
    pbx.append("\t\t\tisa = PBXSourcesBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    for src in test_sources:
        _, b_id, _ = file_refs[src]
        name = os.path.basename(src)
        pbx.append(f"\t\t\t\t{b_id} /* {name} in Sources */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    pbx.append("/* End PBXSourcesBuildPhase section */")

    # PBXTargetDependency
    pbx.append("\n/* Begin PBXTargetDependency section */")
    pbx.append(f"\t\t{id_target_dependency} /* PBXTargetDependency */ = {{")
    pbx.append("\t\t\tisa = PBXTargetDependency;")
    pbx.append(f"\t\t\ttarget = {id_app_target} /* Noty */;")
    pbx.append(f"\t\t\ttargetProxy = {id_container_item_proxy} /* PBXContainerItemProxy */;")
    pbx.append("\t\t};")
    pbx.append("/* End PBXTargetDependency section */")

    # XCBuildConfiguration
    pbx.append("\n/* Begin XCBuildConfiguration section */")
    # Project Debug
    pbx.append(f"\t\t{id_proj_debug_config} /* Debug */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    pbx.append("\t\t\t\tARCHS = arm64;")
    pbx.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    pbx.append("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
    pbx.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    pbx.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    pbx.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
    pbx.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
    pbx.append("\t\t\t\tENABLE_TESTABILITY = YES;")
    pbx.append("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
    pbx.append("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
    pbx.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
    pbx.append("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
    pbx.append("\t\t\t\t\t\"DEBUG=1\",")
    pbx.append("\t\t\t\t\t\"$(inherited)\",")
    pbx.append("\t\t\t\t);")
    pbx.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
    pbx.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
    pbx.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
    pbx.append("\t\t\t\tSDKROOT = macosx;")
    pbx.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
    pbx.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
    pbx.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Debug;")
    pbx.append("\t\t};")

    # Project Release
    pbx.append(f"\t\t{id_proj_release_config} /* Release */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    pbx.append("\t\t\t\tARCHS = arm64;")
    pbx.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    pbx.append("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
    pbx.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    pbx.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    pbx.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
    pbx.append("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
    pbx.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
    pbx.append("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
    pbx.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
    pbx.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
    pbx.append("\t\t\t\tSDKROOT = macosx;")
    pbx.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    pbx.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
    pbx.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Release;")
    pbx.append("\t\t};")

    # Target App Debug
    pbx.append(f"\t\t{id_app_debug_config} /* Debug */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
    pbx.append("\t\t\t\tCODE_SIGN_ENTITLEMENTS = Noty/Resources/Noty.entitlements;")
    pbx.append("\t\t\t\tCODE_SIGN_IDENTITY = \"-\";")
    pbx.append("\t\t\t\tCODE_SIGN_STYLE = Manual;")
    pbx.append("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    pbx.append("\t\t\t\tENABLE_HARDENED_RUNTIME = YES;")
    pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    pbx.append("\t\t\t\tINFOPLIST_FILE = Noty/Resources/Info.plist;")
    pbx.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    pbx.append("\t\t\t\t\t\"$(inherited)\",")
    pbx.append("\t\t\t\t\t\"@executable_path/../Frameworks\",")
    pbx.append("\t\t\t\t);")
    pbx.append("\t\t\t\tMARKETING_VERSION = 1.0.0;")
    pbx.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.libao.noty;")
    pbx.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    pbx.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Debug;")
    pbx.append("\t\t};")

    # Target App Release
    pbx.append(f"\t\t{id_app_release_config} /* Release */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
    pbx.append("\t\t\t\tCODE_SIGN_ENTITLEMENTS = Noty/Resources/Noty.entitlements;")
    pbx.append("\t\t\t\tCODE_SIGN_IDENTITY = \"-\";")
    pbx.append("\t\t\t\tCODE_SIGN_STYLE = Manual;")
    pbx.append("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    pbx.append("\t\t\t\tENABLE_HARDENED_RUNTIME = YES;")
    pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    pbx.append("\t\t\t\tINFOPLIST_FILE = Noty/Resources/Info.plist;")
    pbx.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    pbx.append("\t\t\t\t\t\"$(inherited)\",")
    pbx.append("\t\t\t\t\t\"@executable_path/../Frameworks\",")
    pbx.append("\t\t\t\t);")
    pbx.append("\t\t\t\tMARKETING_VERSION = 1.0.0;")
    pbx.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.libao.noty;")
    pbx.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    pbx.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Release;")
    pbx.append("\t\t};")

    # Target Test Debug
    pbx.append(f"\t\t{id_test_debug_config} /* Debug */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
    pbx.append("\t\t\t\tCODE_SIGN_STYLE = Manual;")
    pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
    pbx.append("\t\t\t\tMARKETING_VERSION = 1.0;")
    pbx.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.libao.noty.NotyTests;")
    pbx.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    pbx.append("\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/Noty.app/Contents/MacOS/Noty\";")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Debug;")
    pbx.append("\t\t};")

    # Target Test Release
    pbx.append(f"\t\t{id_test_release_config} /* Release */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
    pbx.append("\t\t\t\tCODE_SIGN_STYLE = Manual;")
    pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
    pbx.append("\t\t\t\tMARKETING_VERSION = 1.0;")
    pbx.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.libao.noty.NotyTests;")
    pbx.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    pbx.append("\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/Noty.app/Contents/MacOS/Noty\";")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Release;")
    pbx.append("\t\t};")
    pbx.append("/* End XCBuildConfiguration section */")

    # XCConfigurationList
    pbx.append("\n/* Begin XCConfigurationList section */")
    pbx.append(f"\t\t{id_proj_config_list} /* Build configuration list for PBXProject \"Noty\" */ = {{")
    pbx.append("\t\t\tisa = XCConfigurationList;")
    pbx.append("\t\t\tbuildConfigurations = (")
    pbx.append(f"\t\t\t\t{id_proj_debug_config} /* Debug */,")
    pbx.append(f"\t\t\t\t{id_proj_release_config} /* Release */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    pbx.append("\t\t\tdefaultConfigurationName = Release;")
    pbx.append("\t\t};")

    pbx.append(f"\t\t{id_app_config_list} /* Build configuration list for PBXNativeTarget \"Noty\" */ = {{")
    pbx.append("\t\t\tisa = XCConfigurationList;")
    pbx.append("\t\t\tbuildConfigurations = (")
    pbx.append(f"\t\t\t\t{id_app_debug_config} /* Debug */,")
    pbx.append(f"\t\t\t\t{id_app_release_config} /* Release */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    pbx.append("\t\t\tdefaultConfigurationName = Release;")
    pbx.append("\t\t};")

    pbx.append(f"\t\t{id_test_config_list} /* Build configuration list for PBXNativeTarget \"NotyTests\" */ = {{")
    pbx.append("\t\t\tisa = XCConfigurationList;")
    pbx.append("\t\t\tbuildConfigurations = (")
    pbx.append(f"\t\t\t\t{id_test_debug_config} /* Debug */,")
    pbx.append(f"\t\t\t\t{id_test_release_config} /* Release */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    pbx.append("\t\t\tdefaultConfigurationName = Release;")
    pbx.append("\t\t};")
    pbx.append("/* End XCConfigurationList section */")

    pbx.append("\t};")
    pbx.append(f"\trootObject = {id_project} /* Project object */;")
    pbx.append("}")

    with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
        f.write("\n".join(pbx) + "\n")

    # Scheme
    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{id_app_target}"
               BuildableName = "Noty.app"
               BlueprintName = "Noty"
               ReferencedContainer = "container:Noty.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{id_test_target}"
               BuildableName = "NotyTests.xctest"
               BlueprintName = "NotyTests"
               ReferencedContainer = "container:Noty.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{id_app_target}"
            BuildableName = "Noty.app"
            BlueprintName = "Noty"
            ReferencedContainer = "container:Noty.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{id_app_target}"
            BuildableName = "Noty.app"
            BlueprintName = "Noty"
            ReferencedContainer = "container:Noty.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    with open(os.path.join(schemes_dir, "Noty.xcscheme"), "w") as f:
        f.write(scheme)

    print("Successfully generated Noty.xcodeproj")

if __name__ == "__main__":
    main()
