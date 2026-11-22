#!/usr/bin/env python3
from pathlib import Path
import runpy,os
if not os.environ.get("CUSTOMER_VOICE_LOCAL_SDK"):
 raise SystemExit("UI harness requires CUSTOMER_VOICE_LOCAL_SDK pointing to the matching 0.5.0 source checkout (@testable APIs). Shipping demo uses local CocoaPods binaries.")
root=Path(__file__).resolve().parents[1]
m=runpy.run_path(str(root/'scripts/generate-demo-project.py'));add=m['add'];objects=m['objects'];encode=m['encode'];configs=m['configs'];package=m['package'];products=m['products']
refs=[]
def phase(key,paths):
 files=[]
 for name,path in paths:
  ref=add(key+name,'PBXFileReference',lastKnownFileType='sourcecode.swift',path=path,sourceTree='<group>');refs.append(ref);files.append(add(key+name+'build','PBXBuildFile',fileRef=ref))
 return add(key+'sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=files,runOnlyForDeploymentPostprocessing=0)
app=add('harnessapp','PBXFileReference',explicitFileType='wrapper.application',path='CustomerVoiceUIHarness.app',sourceTree='BUILT_PRODUCTS_DIR')
settings={'SDKROOT':'iphonesimulator','IPHONEOS_DEPLOYMENT_TARGET':'15.1','SWIFT_VERSION':'5.0','TARGETED_DEVICE_FAMILY':'1','PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'vn.caresoft.CustomerVoiceUIHarness','INFOPLIST_FILE':'../Demo/Info.plist','VOICE_BACKEND_URL':'https://ui-test.invalid','VOICE_ACCOUNT_ID':'20','VOICE_APP_ID':'fixture-app','VOICE_HOTLINE':'18001234','MARKETING_VERSION':'0.5.0','CURRENT_PROJECT_VERSION':'1','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks','ENABLE_TESTABILITY':'YES'}
harness=add('harness','PBXNativeTarget',name='CustomerVoiceUIHarness',productName='CustomerVoiceUIHarness',productType='com.apple.product-type.application',productReference=app,buildConfigurationList=configs('harness',settings),buildPhases=[phase('harness',[('TestApp','UIHarness/TestApp.swift'),('HomeView','../Demo/HomeView.swift'),('DemoConfig','../Demo/DemoConfig.swift'),('EnterpriseSession','../Demo/EnterpriseSession.swift')]),add('harnessframeworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[add('harness'+p,'PBXBuildFile',productRef=p) for p in products],runOnlyForDeploymentPostprocessing=0)],buildRules=[],dependencies=[],packageProductDependencies=products)
testapp=add('uitestproduct','PBXFileReference',explicitFileType='wrapper.cfbundle',path='CustomerFlowUITests.xctest',sourceTree='BUILT_PRODUCTS_DIR')
proxy=add('harnessproxy','PBXContainerItemProxy',containerPortal=m['project'],proxyType=1,remoteGlobalIDString=harness,remoteInfo='CustomerVoiceUIHarness');dep=add('harnessdep','PBXTargetDependency',target=harness,targetProxy=proxy)
test=add('uitests','PBXNativeTarget',name='CustomerFlowUITests',productName='CustomerFlowUITests',productType='com.apple.product-type.bundle.ui-testing',productReference=testapp,buildConfigurationList=configs('uitests',{'SDKROOT':'iphonesimulator','IPHONEOS_DEPLOYMENT_TARGET':'15.1','SWIFT_VERSION':'5.0','PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'vn.caresoft.CustomerFlowUITests','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'CustomerVoiceUIHarness','ENABLE_TESTABILITY':'YES'}),buildPhases=[phase('uitests',[('CustomerFlowUITests','UITests/CustomerFlowUITests.swift')])],buildRules=[],dependencies=[dep])
objects[m['project']]['targets']=[harness,test];objects[m['group']]['children']=refs+[app,testapp]
d=root/'Tests/UITestHarness.xcodeproj';d.mkdir(parents=True,exist_ok=True);(d/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':1,'classes':{},'objectVersion':60,'objects':objects,'rootObject':m['project']})+'\n')
s=d/'xcshareddata/xcschemes';s.mkdir(parents=True,exist_ok=True)
def ref(i,n):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{i}" BuildableName="{n}" BlueprintName="{n.split(".")[0]}" ReferencedContainer="container:UITestHarness.xcodeproj"/>'
(s/'CustomerFlowUITests.xcscheme').write_text(f'<?xml version="1.0"?><Scheme version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{ref(harness,"CustomerVoiceUIHarness.app")}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref(test,"CustomerFlowUITests.xctest")}</TestableReference></Testables></TestAction></Scheme>')
print(d)
