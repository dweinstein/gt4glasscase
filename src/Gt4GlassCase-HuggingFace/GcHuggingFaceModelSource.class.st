"
ADAPTER: implements the GcModelSource port using a Gt4HuggingFaceClient. The only class that references both the HuggingFace client and Gc domain objects -- it translates generic Hub results (config Dictionary, safetensors header) into GcModelConfig / GcSafetensorsFile / GcRepoManifest. Reads the optional token from ~/.secrets/huggingface-token.txt inside the image and injects it into the client.
"
Class {
	#name : 'GcHuggingFaceModelSource',
	#superclass : 'GcModelSource',
	#instVars : [
		'client',
		'repositoryId',
		'cachedConfig',
		'cachedFile'
	],
	#category : 'Gt4GlassCase-HuggingFace',
	#package : 'Gt4GlassCase-HuggingFace'
}

{ #category : 'instance creation' }
GcHuggingFaceModelSource class >> forRepository: aRepoId [
	^ self new
		repositoryId: aRepoId;
		yourself
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> architecture [
	^ self config architecture
]

{ #category : 'fetching' }
GcHuggingFaceModelSource >> architectureFor: aRepoId [
	^ (self configFor: aRepoId) architecture
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> clearCache [
	"Drop cached config/file so the next access re-fetches."
	cachedConfig := nil.
	cachedFile := nil
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> client [
	^ client
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> client: aClient [
	client := aClient
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> config [
	"Cached: fetched once per source."
	^ cachedConfig ifNil: [ cachedConfig := self configFor: repositoryId ]
]

{ #category : 'fetching' }
GcHuggingFaceModelSource >> configFor: aRepoId [
	^ GcModelConfig fromDictionary: (client config: aRepoId)
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> fileInfo [
	^ self fileInfo: 'model.safetensors'
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> fileInfo: aFileName [
	"The safetensors file with its full tensor tree (like HuggingFace's file-info panel). Open the result's Tree view."
	^ self safetensorsFile: aFileName
]

{ #category : 'views' }
GcHuggingFaceModelSource >> gtArchitectureFor: aView [
	"The model architecture. Fetches config.json the first time this tab is opened (then cached)."
	<gtView>
	^ aView forward
		title: 'Architecture';
		priority: 3;
		object: [ self architecture ];
		view: #gtOverviewFor:
]

{ #category : 'views' }
GcHuggingFaceModelSource >> gtSkylineFor: aView [
	"The model skyline. Fetches the safetensors header the first time this tab is opened (then cached)."
	<gtView>
	^ aView forward
		title: 'Skyline';
		priority: 5;
		object: [ self tensorGroup ];
		view: #gtSkylineFor:
]

{ #category : 'views' }
GcHuggingFaceModelSource >> gtSourceFor: aView [
	"What model does this source point at? No network -- this is the safe default view."
	<gtView>
	^ aView columnedList
		title: 'Source';
		priority: 1;
		items: [ self sourceFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | v displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'views' }
GcHuggingFaceModelSource >> gtTreeFor: aView [
	"The tensor tree (HuggingFace-style file info). Fetches the safetensors header the first time this tab is opened (then cached)."
	<gtView>
	^ aView forward
		title: 'Tree';
		priority: 4;
		object: [ self tensorTree ];
		view: #gtTreeFor:
]

{ #category : 'initialization' }
GcHuggingFaceModelSource >> initialize [
	super initialize.
	client := Gt4HuggingFaceClient new.
	self injectTokenIfPresent
]

{ #category : 'initialization' }
GcHuggingFaceModelSource >> injectTokenIfPresent [
	"Read the optional HF token from a local secrets file inside the image and inject it into the client. The token value is never printed or returned."
	| ref |
	ref := FileLocator home / '.secrets' / 'huggingface-token.txt'.
	ref exists ifTrue: [ client token: ref contents trimmed ]
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> manifest [
	^ self manifestFor: repositoryId
]

{ #category : 'fetching' }
GcHuggingFaceModelSource >> manifestFor: aRepoId [
	| tree manifest |
	tree := client fileTree: aRepoId.
	manifest := GcRepoManifest new.
	tree do: [ :entry |
		(entry at: 'type' ifAbsent: [ 'file' ]) = 'file' ifTrue: [
			manifest addFile: (GcFileDigest
				path: (entry at: 'path' ifAbsent: [ nil ])
				size: (entry at: 'size' ifAbsent: [ nil ])
				sha256: ((entry at: 'lfs' ifAbsent: [ nil ])
					ifNotNil: [ :lfs | lfs at: 'oid' ifAbsent: [ nil ] ]
					ifNil: [ entry at: 'oid' ifAbsent: [ nil ] ])) ] ].
	^ manifest
]

{ #category : 'printing' }
GcHuggingFaceModelSource >> printOn: aStream [
	aStream nextPutAll: 'GcHuggingFaceModelSource('.
	aStream nextPutAll: (repositoryId ifNil: [ '?' ]).
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> repositoryId [
	^ repositoryId
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> repositoryId: aString [
	repositoryId := aString
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> safetensorsFile [
	"The default model.safetensors, cached: header fetched once per source."
	^ cachedFile ifNil: [ cachedFile := self safetensorsFile: 'model.safetensors' ]
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> safetensorsFile: aFileName [
	^ self safetensorsFileFor: repositoryId file: aFileName
]

{ #category : 'fetching' }
GcHuggingFaceModelSource >> safetensorsFileFor: aRepoId file: aFileName [
	"Translate the generic safetensors header into a GcSafetensorsFile of GcTensorRefs. The core class parses a plain Dictionary, so it stays decoupled from the HF client."
	| header file |
	header := client safetensorsHeader: aRepoId file: aFileName.
	file := GcSafetensorsFile new.
	file path: aRepoId, '/', aFileName.
	file parseHeaderDictionary: header rawDictionary.
	^ file
]

{ #category : 'views' }
GcHuggingFaceModelSource >> sourceFacets [
	^ {
		'Repository' -> repositoryId.
		'Base URL' -> client baseUrl.
		'Token' -> (client hasToken ifTrue: [ 'present' ] ifFalse: [ 'none (public)' ]).
		'Default file' -> 'model.safetensors' }
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> tensorGroup [
	^ self safetensorsFile tensorGroup
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> tensorTree [
	^ self safetensorsFile tensorTree
]
