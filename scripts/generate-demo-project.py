#!/usr/bin/env python3
"""Reproducible Xcode source-package demo; Python standard library only."""
from pathlib import Path
import hashlib,json,os
root=Path(__file__).resolve().parents[1];objects={}
def add(key,isa,**fields):
 i=hashlib.sha256(key.encode()).hexdigest()[:24].upper();objects[i]={'isa':isa,**fields};return i
def encode(v):
 if isinstance(v,dict):return '{ '+' '.join(json.dumps(k)+' = '+encode(x)+';' for k,x in v.items())+' }'
 if isinstance(v,list):return '('+','.join(encode(x) for x in v)+')'
 return json.dumps(str(v))
def configs(key,settings,base=None):
 refs=[add(key+mode,'XCBuildConfiguration',name=mode,buildSettings={**settings,'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O',**({'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG'} if mode=='Debug' else {})},**({'baseConfigurationReference':base[mode] if isinstance(base,dict) else base} if base else {})) for mode in ['Debug','Release']]
 return add(key+'list','XCConfigurationList',buildConfigurations=refs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
base=add('config','PBXFileReference',lastKnownFileType='text.xcconfig',path='Defaults.xcconfig',sourceTree='<group>');refs=[];sourcefiles=[]
podconfigs={mode:add(mode+'config','PBXFileReference',lastKnownFileType='text.xcconfig',path=mode+'.xcconfig',sourceTree='<group>') for mode in ['Debug','Release']}
base=podconfigs
configrefs=list(podconfigs.values())+[add(name,'PBXFileReference',lastKnownFileType='text.xcconfig',path=name,sourceTree='<group>') for name in ['Config.example.xcconfig','Local.xcconfig']]
configgroup=add('configgroup','PBXGroup',children=configrefs,path='Config',sourceTree='<group>')
metadata=[add(name,'PBXFileReference',lastKnownFileType='text.plist.entitlements' if name.endswith('entitlements') else 'text.plist.xml',path=name,sourceTree='<group>') for name in ['Info.plist','Demo.entitlements']]
for name in ['DemoApp.swift','HomeView.swift','DemoConfig.swift','EnterpriseSession.swift']:
 r=add(name,'PBXFileReference',lastKnownFileType='sourcecode.swift',path=name,sourceTree='<group>');refs.append(r);sourcefiles.append(add(name+'build','PBXBuildFile',fileRef=r))
local_sdk=os.environ.get('CUSTOMER_VOICE_LOCAL_SDK')
if local_sdk:
 package=add('package','XCLocalSwiftPackageReference',relativePath=os.path.relpath(Path(local_sdk).resolve(),root/'Demo'))
else:
 package=None  # Default consumer links the checksummed binary SDK via CocoaPods.
products=[];frameworks=[]
for name in (['CustomerVoice','CustomerVoiceUI'] if package else []):
 p=add(name,'XCSwiftPackageProductDependency',productName=name,package=package);products.append(p);frameworks.append(add(name+'build','PBXBuildFile',productRef=p))
app=add('app','PBXFileReference',explicitFileType='wrapper.application',path='CustomerVoiceDemo.app',sourceTree='BUILT_PRODUCTS_DIR')
pg=add('products','PBXGroup',children=[app],name='Products',sourceTree='<group>');group=add('main','PBXGroup',children=refs+metadata+[configgroup,pg],sourceTree='<group>')
asset=add('assets','PBXFileReference',lastKnownFileType='folder.assetcatalog',path='Images.xcassets',sourceTree='<group>');objects[group]['children'].append(asset)
assetbuild=add('assetsbuild','PBXBuildFile',fileRef=asset)
phases=[add('sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=sourcefiles,runOnlyForDeploymentPostprocessing=0),add('frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=frameworks,runOnlyForDeploymentPostprocessing=0),add('resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=[assetbuild],runOnlyForDeploymentPostprocessing=0)]
settings={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'15.1','SWIFT_VERSION':'5.0','TARGETED_DEVICE_FAMILY':'1,2','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','CODE_SIGN_STYLE':'Automatic','CODE_SIGN_ENTITLEMENTS':'Demo.entitlements','INFOPLIST_FILE':'Info.plist','PRODUCT_NAME':'$(TARGET_NAME)','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks'}
target=add('target','PBXNativeTarget',name='CustomerVoiceDemo',productName='CustomerVoiceDemo',productType='com.apple.product-type.application',productReference=app,buildConfigurationList=configs('target',settings,base),buildPhases=phases,buildRules=[],dependencies=[],packageProductDependencies=products)
project=add('project','PBXProject',attributes={'LastUpgradeCheck':'2600','TargetAttributes':{target:{'SystemCapabilities':{'com.apple.Push':{'enabled':1},'com.apple.BackgroundModes':{'enabled':1}}}}},buildConfigurationList=configs('project',{'CLANG_ENABLE_MODULES':'YES'}),compatibilityVersion='Xcode 15.0',developmentRegion='vi',knownRegions=['vi','en','Base'],mainGroup=group,productRefGroup=pg,projectDirPath='',projectRoot='',targets=[target],packageReferences=([package] if package else []))
d=root/'Demo/CustomerVoiceDemo.xcodeproj';d.mkdir(parents=True,exist_ok=True);(d/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':1,'classes':{},'objectVersion':60,'objects':objects,'rootObject':project})+'\n')
s=d/'xcshareddata/xcschemes';s.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="CustomerVoiceDemo.app" BlueprintName="CustomerVoiceDemo" ReferencedContainer="container:CustomerVoiceDemo.xcodeproj"/>'
(s/'CustomerVoiceDemo.xcscheme').write_text(f'<?xml version="1.0"?><Scheme LastUpgradeVersion="2600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>')
print(d)
