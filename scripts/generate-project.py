#!/usr/bin/env python3
"""Generate a dependency-free Xcode project with host and embedded WidgetKit extension."""
from pathlib import Path
import hashlib, json, plistlib
root = Path(__file__).resolve().parent.parent
objects = {}
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(object_key, isa, **values):
    key=ident(object_key); objects[key]={'isa':isa, **values}; return key
project=ident('project'); host=ident('host'); widget=ident('widget')
product_host=add('product-host','PBXFileReference',explicitFileType='wrapper.application',path='Glassist.app',sourceTree='BUILT_PRODUCTS_DIR')
product_widget=add('product-widget','PBXFileReference',explicitFileType='wrapper.app-extension',path='GlassistWidgets.appex',sourceTree='BUILT_PRODUCTS_DIR')
files={}
for f in sorted((root/'Sources').rglob('*.swift')):
    path=str(f.relative_to(root)); files[path]=add(path,'PBXFileReference',lastKnownFileType='sourcecode.swift',path=path,sourceTree='<group>')
configrefs=[]
for name in ['App.entitlements','Widget.entitlements','App-Info.plist','Widget-Info.plist']:
    configrefs.append(add(name,'PBXFileReference',lastKnownFileType='text.plist.xml',path='Configuration/'+name,sourceTree='<group>'))
signing=add('signing-config','PBXFileReference',lastKnownFileType='text.xcconfig',path='Configuration/Signing.xcconfig',sourceTree='<group>')
configrefs.append(signing)
localized=[]
for language in ['en','zh-Hans']:
    path=f'Sources/GlassistCore/Resources/{language}.lproj/Localizable.strings'
    localized.append(add('strings-'+language,'PBXFileReference',lastKnownFileType='text.plist.strings',name=language,path=path,sourceTree='<group>'))
strings=add('localized-strings','PBXVariantGroup',children=localized,name='Localizable.strings',sourceTree='<group>')
configrefs.append(strings)
intentrefs=[]
for language in ['en','zh-Hans']:
    path=f'Sources/GlassistCore/Resources/{language}.lproj/WidgetIntents.strings'
    intentrefs.append(add('intent-strings-'+language,'PBXFileReference',lastKnownFileType='text.plist.strings',name=language,path=path,sourceTree='<group>'))
intentstrings=add('localized-intent-strings','PBXVariantGroup',children=intentrefs,name='WidgetIntents.strings',sourceTree='<group>')
configrefs.append(intentstrings)
assets=add('app-assets','PBXFileReference',lastKnownFileType='folder.assetcatalog',path='Resources/Assets.xcassets',sourceTree='<group>')
privacy=add('privacy-manifest','PBXFileReference',lastKnownFileType='text.xml',path='Configuration/PrivacyInfo.xcprivacy',sourceTree='<group>')
configrefs.extend([assets,privacy])
products=add('products','PBXGroup',children=[product_host,product_widget],name='Products',sourceTree='<group>')
main=add('main','PBXGroup',children=list(files.values())+configrefs+[products],sourceTree='<group>')
base={'MACOSX_DEPLOYMENT_TARGET':'14.0','SDKROOT':'macosx','SWIFT_VERSION':'5.0','ARCHS':'arm64','CLANG_ENABLE_MODULES':'YES',
      'CODE_SIGN_STYLE':'Automatic','ENABLE_HARDENED_RUNTIME':'YES',
      'REGISTER_APP_GROUPS':'YES','SWIFT_EMIT_LOC_STRINGS':'YES','CURRENT_PROJECT_VERSION':'7','MARKETING_VERSION':'0.4.0'}
def configs(name, extra):
    refs=[]
    for mode in ['Debug','Release']:
        settings={**extra}
        settings.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O',
                         'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if mode=='Debug' else '',
                         'DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym'})
        config={'baseConfigurationReference':signing} if name=='project' else {}
        refs.append(add(name+mode,'XCBuildConfiguration',buildSettings=settings,name=mode,**config))
    return add(name+'configlist','XCConfigurationList',buildConfigurations=refs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
for name, targetID, selected, product, bundle, info, entitlements, producttype in [
    ('host',host,['Glassist','GlassistCore'],product_host,'com.frankwang.Glassist','App-Info.plist','App.entitlements','com.apple.product-type.application'),
    ('widget',widget,['GlassistWidgets','GlassistCore'],product_widget,'com.frankwang.Glassist.Widgets','Widget-Info.plist','Widget.entitlements','com.apple.product-type.app-extension')]:
    builds=[add(name+path,'PBXBuildFile',fileRef=ref) for path,ref in files.items() if path.split('/')[1] in selected]
    sources=add(name+'sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=builds,runOnlyForDeploymentPostprocessing=0)
    frameworks=add(name+'frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
    resourcefile=add(name+'localized-resource','PBXBuildFile',fileRef=strings)
    intentresource=add(name+'localized-intent-resource','PBXBuildFile',fileRef=intentstrings)
    privacyresource=add(name+'privacy-resource','PBXBuildFile',fileRef=privacy)
    resourcefiles=[resourcefile,intentresource,privacyresource]
    if name=='host': resourcefiles.append(add('host-assets-resource','PBXBuildFile',fileRef=assets))
    resources=add(name+'resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=resourcefiles,runOnlyForDeploymentPostprocessing=0)
    phases=[sources,frameworks,resources]; dependencies=[]
    if name=='host':
        embedfile=add('embedfile','PBXBuildFile',fileRef=product_widget,settings={'ATTRIBUTES':['CodeSignOnCopy','RemoveHeadersOnCopy']})
        phases.append(add('embed','PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=13,files=[embedfile],name='Embed App Extensions',runOnlyForDeploymentPostprocessing=0))
        proxy=add('proxy','PBXContainerItemProxy',containerPortal=project,proxyType=1,remoteGlobalIDString=widget,remoteInfo='GlassistWidgets')
        dependencies=[add('dependency','PBXTargetDependency',target=widget,targetProxy=proxy)]
    settings={'PRODUCT_NAME':'Glassist' if name=='host' else 'GlassistWidgets','PRODUCT_BUNDLE_IDENTIFIER':bundle,
              'INFOPLIST_FILE':'Configuration/'+info,'CODE_SIGN_ENTITLEMENTS':'Configuration/'+entitlements,
              'LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/../Frameworks','@executable_path/../../../../Frameworks'],
              'SKIP_INSTALL':'YES' if name=='widget' else 'NO','ENABLE_APP_SANDBOX':'YES',
              'APPLICATION_EXTENSION_API_ONLY':'YES' if name=='widget' else 'NO'}
    if name=='host': settings['ASSETCATALOG_COMPILER_APPICON_NAME']='AppIcon'
    objects[targetID]={'isa':'PBXNativeTarget','buildConfigurationList':configs(name,settings),'buildPhases':phases,'buildRules':[],
                       'dependencies':dependencies,'name':settings['PRODUCT_NAME'],'productName':settings['PRODUCT_NAME'],
                       'productReference':product,'productType':producttype}
objects[project]={'isa':'PBXProject','attributes':{'LastUpgradeCheck':'1600','BuildIndependentTargetsInParallel':'YES',
    'TargetAttributes':{host:{'SystemCapabilities':{'com.apple.ApplicationGroups.iOS':{'enabled':1}}},widget:{'SystemCapabilities':{'com.apple.ApplicationGroups.iOS':{'enabled':1}}}}},
    'buildConfigurationList':configs('project',base),'compatibilityVersion':'Xcode 14.0','developmentRegion':'en','hasScannedForEncodings':0,
    'knownRegions':['en','Base','zh-Hans'],'mainGroup':main,'productRefGroup':products,'projectDirPath':'','projectRoot':'','targets':[host,widget]}
def serialize(value, depth=0):
    if isinstance(value,dict): return '{\n'+''.join('\t'*(depth+1)+json.dumps(str(k))+ ' = '+serialize(v,depth+1)+';\n' for k,v in value.items())+'\t'*depth+'}'
    if isinstance(value,list): return '('+','.join(serialize(v,depth) for v in value)+')'
    if isinstance(value,int): return str(value)
    return json.dumps(value,ensure_ascii=False)
projectdir=root/'Glassist.xcodeproj'; projectdir.mkdir(exist_ok=True)
(projectdir/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':project})+'\n')
schemes=projectdir/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
(schemes/'Glassist.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{host}" BuildableName="Glassist.app" BlueprintName="Glassist" ReferencedContainer="container:Glassist.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug"/><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{host}" BuildableName="Glassist.app" BlueprintName="Glassist" ReferencedContainer="container:Glassist.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
common={'CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)',
        'CFBundleDevelopmentRegion':'en','CFBundleLocalizations':['en','zh-Hans'],
        'CFBundleName':'$(PRODUCT_NAME)','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)',
        'LSMinimumSystemVersion':'$(MACOSX_DEPLOYMENT_TARGET)','GlassistAppGroup':'$(GLASSIST_GROUP_ID)',
        'GlassistKeychainGroup':'$(AppIdentifierPrefix)com.frankwang.Glassist.shared'}
for name in ['App','Widget']:
    info={**common,'CFBundlePackageType':'APPL' if name=='App' else 'XPC!'}
    if name=='App':
        info['CFBundleURLTypes']=[{'CFBundleURLName':'com.frankwang.Glassist','CFBundleURLSchemes':['glassist']}]
        info['LSApplicationCategoryType']='public.app-category.productivity'
        info['NSHumanReadableCopyright']='Copyright © 2026 Frank Wang'
    else: info['NSExtension']={'NSExtensionPointIdentifier':'com.apple.widgetkit-extension'}
    (root/'Configuration'/f'{name}-Info.plist').write_bytes(plistlib.dumps(info))
    (root/'Configuration'/f'{name}.entitlements').write_bytes(plistlib.dumps({'com.apple.security.app-sandbox':True,
        'com.apple.security.network.client':True,'com.apple.security.application-groups':['$(GLASSIST_GROUP_ID)'],
        'keychain-access-groups':['$(AppIdentifierPrefix)com.frankwang.Glassist.shared']}))
print('Generated Glassist.xcodeproj with embedded WidgetKit extension.')
