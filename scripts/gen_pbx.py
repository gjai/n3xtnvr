#!/usr/bin/env python3
"""Génère project.pbxproj avec des UUID Xcode valides (24 caractères hex)."""
import pathlib

U = """
45A90771F861A099C13A8CF1 0A62CE730BD0E61A54EA341B 328BCA44DC3E9A1069D8BB98 F004957DF012A7F497FD03CE B5E02452FA4BDB255F9D094B
27498B1854E2CA0BC237E263 79BB5A6409A1A117FC8E5871 52D843CD0AA38BBD5D01F314 4AF01FC404F9C6FEDEEEA2E0 69A3525FF55F58870D25265E
7801A2C91457C616B7CB64CF 1E147099234E5838EE3B6159 48A7DC60E0D78EE3E6973CDB 09B938F7AD5B29582BA37195 B0EB37FB23CC61FD8BA26CED
EF1709EEEFA47A7DECB436DB F65DAB10F2B91E8218A62304 2D4C291DFA637F37C232F214 3698C23D4D8BC31D8E8B04F2 9D2F5DC0C0F8A44256324B33
2767320CA0D058BB27847BA5 153788444F3C211B0D4F24D7 36CC8AF4559F51BE23A93FA5 059BD1080B074A1369B38A07 68A97D7CB920CA55FE3398E7
A09D719F65F0C13A02A02CC1 77037F482B1F8B3486EAAE74 4CF5DD320C09E591F3741C5D 0EBE7A3A8ED5EE92D43D1A65 B0FC57CB2E3C39FE1EC465DC
377D90FEAD03DD1FD702A169 914625133AD58E89F6F85437 08FFE1946A92C41AFFFBA236 F23267AF5706D158E95B587D DE56026A640B1636D61C8D81 7E8C00EDF1C68DBFDA8D9241 6BD20151C39AB7276C5673B4 835A0F8AEACAF9CCABB99BAB 961FDBBE9E2962FC16675C1A
6C9858810E4943591EAC78C3 EA87EA48207AAD59DBB0ACE7 50E6350E3489A6C72FBAF89B 1A4A0F4F3B67168B6A226BE6 CAD38FDB55015C790C286E3A
3E861E5FA14DB8308770C9D2
""".split()
assert all(len(x) == 24 for x in U)
i = 0


def take():
    global i
    r = U[i]
    i += 1
    return r


PRJ = take()
ROOT = take()
NGRP = take()
PGRP = take()
APP = take()
MG = take()
SG = take()
VG = take()
TGT = take()
SRC_PH = take()
FR_PH = take()
RES_PH = take()
TG_CFG = take()
PRJ_CFG = take()

swift = []
for name in [
    "N3xtNVRApp.swift",
    "ContentView.swift",
    "NVRConnectionSettings.swift",
    "AppSession.swift",
    "DVRIPClient.swift",
    "NVRDiscoveryService.swift",
    "LoginView.swift",
    "MainDashboardView.swift",
    "CameraGridView.swift",
    "RTSPPlayerCell.swift",
    "MacAVPlayerView.swift",
    "NVRDiscoveryView.swift",
]:
    swift.append((name, take(), take()))

ASSET_FR = take()
ASSET_BR = take()
INFO_FR = take()
PRJ_DBG = take()
PRJ_REL = take()
TG_DBG = take()
TG_REL = take()

out = []
W = out.append
W("// !$*UTF8*$!")
W("{")
W("\tarchiveVersion = 1;")
W("\tclasses = {")
W("\t};")
W("\tobjectVersion = 56;")
W("\tobjects = {")
W("")
W("/* Begin PBXBuildFile section */")
for name, fr, br in swift:
    W(f"\t\t{br} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};")
W(f"\t\t{ASSET_BR} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ASSET_FR} /* Assets.xcassets */; }};")
W("/* End PBXBuildFile section */")
W("")
W("/* Begin PBXFileReference section */")
W(f"\t\t{APP} /* N3xtNVR.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = N3xtNVR.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for name, fr, _ in swift:
    W(f"\t\t{fr} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};")
W(f"\t\t{ASSET_FR} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
W(f"\t\t{INFO_FR} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
W("/* End PBXFileReference section */")
W("")
W("/* Begin PBXFrameworksBuildPhase section */")
W(f"\t\t{FR_PH} /* Frameworks */ = {{")
W("\t\t\tisa = PBXFrameworksBuildPhase;")
W("\t\t\tbuildActionMask = 2147483647;")
W("\t\t\tfiles = (")
W("\t\t\t);")
W("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W("\t\t};")
W("/* End PBXFrameworksBuildPhase section */")
W("")
W("/* Begin PBXGroup section */")
W(f"\t\t{ROOT} = {{")
W("\t\t\tisa = PBXGroup;")
W("\t\t\tchildren = (")
W(f"\t\t\t\t{NGRP} /* N3xtNVR */,")
W(f"\t\t\t\t{PGRP} /* Products */,")
W("\t\t\t);")
W("\t\t\tsourceTree = \"<group>\";")
W("\t\t};")

W(f"\t\t{NGRP} /* N3xtNVR */ = {{")
W("\t\t\tisa = PBXGroup;")
W("\t\t\tchildren = (")
W(f"\t\t\t\t{swift[0][1]} /* N3xtNVRApp.swift */,")
W(f"\t\t\t\t{swift[1][1]} /* ContentView.swift */,")
W(f"\t\t\t\t{MG} /* Models */,")
W(f"\t\t\t\t{SG} /* Services */,")
W(f"\t\t\t\t{VG} /* Views */,")
W(f"\t\t\t\t{ASSET_FR} /* Assets.xcassets */,")
W(f"\t\t\t\t{INFO_FR} /* Info.plist */,")
W("\t\t\t);")
W("\t\t\tpath = N3xtNVR;")
W("\t\t\tsourceTree = \"<group>\";")
W("\t\t};")

W(f"\t\t{PGRP} /* Products */ = {{")
W("\t\t\tisa = PBXGroup;")
W("\t\t\tchildren = (")
W(f"\t\t\t\t{APP} /* N3xtNVR.app */,")
W("\t\t\t);")
W("\t\t\tname = Products;")
W("\t\t\tsourceTree = \"<group>\";")
W("\t\t};")

W(f"\t\t{MG} /* Models */ = {{")
W("\t\t\tisa = PBXGroup;")
W("\t\t\tchildren = (")
W(f"\t\t\t\t{swift[2][1]} /* NVRConnectionSettings.swift */,")
W(f"\t\t\t\t{swift[3][1]} /* AppSession.swift */,")
W("\t\t\t);")
W("\t\t\tpath = Models;")
W("\t\t\tsourceTree = \"<group>\";")
W("\t\t};")

W(f"\t\t{SG} /* Services */ = {{")
W("\t\t\tisa = PBXGroup;")
W("\t\t\tchildren = (")
W(f"\t\t\t\t{swift[4][1]} /* DVRIPClient.swift */,")
W(f"\t\t\t\t{swift[5][1]} /* NVRDiscoveryService.swift */,")
W("\t\t\t);")
W("\t\t\tpath = Services;")
W("\t\t\tsourceTree = \"<group>\";")
W("\t\t};")

W(f"\t\t{VG} /* Views */ = {{")
W("\t\t\tisa = PBXGroup;")
W("\t\t\tchildren = (")
for n, fr, _ in swift[6:]:
    W(f"\t\t\t\t{fr} /* {n} */,")
W("\t\t\t);")
W("\t\t\tpath = Views;")
W("\t\t\tsourceTree = \"<group>\";")
W("\t\t};")
W("/* End PBXGroup section */")
W("")
W("/* Begin PBXNativeTarget section */")
W(f"\t\t{TGT} /* N3xtNVR */ = {{")
W("\t\t\tisa = PBXNativeTarget;")
W(f"\t\t\tbuildConfigurationList = {TG_CFG} /* Build configuration list for PBXNativeTarget \"N3xtNVR\" */;")
W("\t\t\tbuildPhases = (")
W(f"\t\t\t\t{SRC_PH} /* Sources */,")
W(f"\t\t\t\t{FR_PH} /* Frameworks */,")
W(f"\t\t\t\t{RES_PH} /* Resources */,")
W("\t\t\t);")
W("\t\t\tbuildRules = (")
W("\t\t\t);")
W("\t\t\tdependencies = (")
W("\t\t\t);")
W("\t\t\tname = N3xtNVR;")
W("\t\t\tproductName = N3xtNVR;")
W(f"\t\t\tproductReference = {APP} /* N3xtNVR.app */;")
W('\t\t\tproductType = "com.apple.product-type.application";')
W("\t\t};")
W("/* End PBXNativeTarget section */")
W("")
W("/* Begin PBXProject section */")
W(f"\t\t{PRJ} /* Project object */ = {{")
W("\t\t\tisa = PBXProject;")
W("\t\t\tattributes = {")
W("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
W("\t\t\t\tLastSwiftUpdateCheck = 1600;")
W("\t\t\t\tLastUpgradeCheck = 1600;")
W("\t\t\t\tTargetAttributes = {")
W(f"\t\t\t\t\t{TGT} = {{")
W("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
W("\t\t\t\t\t};")
W("\t\t\t\t};")
W("\t\t\t};")
W(f"\t\t\tbuildConfigurationList = {PRJ_CFG} /* Build configuration list for PBXProject \"N3xtNVR\" */;")
W('\t\t\tcompatibilityVersion = "Xcode 14.0";')
W("\t\t\tdevelopmentRegion = fr;")
W("\t\t\thasScannedForEncodings = 0;")
W("\t\t\tknownRegions = (")
W("\t\t\t\ten,")
W("\t\t\t\tBase,")
W("\t\t\t\tfr,")
W("\t\t\t);")
W(f"\t\t\tmainGroup = {ROOT};")
W(f"\t\t\tproductRefGroup = {PGRP} /* Products */;")
W('\t\t\tprojectDirPath = "";')
W('\t\t\tprojectRoot = "";')
W("\t\t\ttargets = (")
W(f"\t\t\t\t{TGT} /* N3xtNVR */,")
W("\t\t\t);")
W("\t\t};")
W("/* End PBXProject section */")
W("")
W("/* Begin PBXResourcesBuildPhase section */")
W(f"\t\t{RES_PH} /* Resources */ = {{")
W("\t\t\tisa = PBXResourcesBuildPhase;")
W("\t\t\tbuildActionMask = 2147483647;")
W("\t\t\tfiles = (")
W(f"\t\t\t\t{ASSET_BR} /* Assets.xcassets in Resources */,")
W("\t\t\t);")
W("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W("\t\t};")
W("/* End PBXResourcesBuildPhase section */")
W("")
W("/* Begin PBXSourcesBuildPhase section */")
W(f"\t\t{SRC_PH} /* Sources */ = {{")
W("\t\t\tisa = PBXSourcesBuildPhase;")
W("\t\t\tbuildActionMask = 2147483647;")
W("\t\t\tfiles = (")
for name, _, br in swift:
    W(f"\t\t\t\t{br} /* {name} in Sources */,")
W("\t\t\t);")
W("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W("\t\t};")
W("/* End PBXSourcesBuildPhase section */")
W("")
W("/* Begin XCBuildConfiguration section */")
# Project-level
W(f"\t\t{PRJ_DBG} /* Debug */ = {{")
W("\t\t\tisa = XCBuildConfiguration;")
W("\t\t\tbuildSettings = {")
for line in """\
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MACOSX_DEPLOYMENT_TARGET = 15.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";""".split("\n"):
    W("\t\t\t" + line)
W("\t\t\t};")
W("\t\t\tname = Debug;")
W("\t\t};")

W(f"\t\t{PRJ_REL} /* Release */ = {{")
W("\t\t\tisa = XCBuildConfiguration;")
W("\t\t\tbuildSettings = {")
for line in """\
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_NO_COMMON_BLOCKS = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MACOSX_DEPLOYMENT_TARGET = 15.0;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;""".split("\n"):
    W("\t\t\t" + line)
W("\t\t\t};")
W("\t\t\tname = Release;")
W("\t\t};")

# Target-level
W(f"\t\t{TG_DBG} /* Debug */ = {{")
W("\t\t\tisa = XCBuildConfiguration;")
W("\t\t\tbuildSettings = {")
for line in """\
				"ARCHS[sdk=macosx*]" = arm64;
				ASSETCATALOG_COMPILER_APPICON_NAME = "";
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = "";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = N3xtNVR/Info.plist;
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.n3xtnvr.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;""".split("\n"):
    W("\t\t\t" + line)
W("\t\t\t};")
W("\t\t\tname = Debug;")
W("\t\t};")

W(f"\t\t{TG_REL} /* Release */ = {{")
W("\t\t\tisa = XCBuildConfiguration;")
W("\t\t\tbuildSettings = {")
for line in """\
				"ARCHS[sdk=macosx*]" = arm64;
				ASSETCATALOG_COMPILER_APPICON_NAME = "";
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = "";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = N3xtNVR/Info.plist;
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.n3xtnvr.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;""".split("\n"):
    W("\t\t\t" + line)
W("\t\t\t};")
W("\t\t\tname = Release;")
W("\t\t};")
W("/* End XCBuildConfiguration section */")
W("")
W("/* Begin XCConfigurationList section */")
W(f"\t\t{TG_CFG} /* Build configuration list for PBXNativeTarget \"N3xtNVR\" */ = {{")
W("\t\t\tisa = XCConfigurationList;")
W("\t\t\tbuildConfigurations = (")
W(f"\t\t\t\t{TG_DBG} /* Debug */,")
W(f"\t\t\t\t{TG_REL} /* Release */,")
W("\t\t\t);")
W("\t\t\tdefaultConfigurationIsVisible = 0;")
W("\t\t\tdefaultConfigurationName = Release;")
W("\t\t};")
W(f"\t\t{PRJ_CFG} /* Build configuration list for PBXProject \"N3xtNVR\" */ = {{")
W("\t\t\tisa = XCConfigurationList;")
W("\t\t\tbuildConfigurations = (")
W(f"\t\t\t\t{PRJ_DBG} /* Debug */,")
W(f"\t\t\t\t{PRJ_REL} /* Release */,")
W("\t\t\t);")
W("\t\t\tdefaultConfigurationIsVisible = 0;")
W("\t\t\tdefaultConfigurationName = Release;")
W("\t\t};")
W("/* End XCConfigurationList section */")
W("\t};")
W(f"rootObject = {PRJ} /* Project object */;")
W("}")

root = pathlib.Path(__file__).resolve().parents[1] / "N3xtNVR.xcodeproj" / "project.pbxproj"
root.write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"Written {root}")
assert i == len(U), (i, len(U))
