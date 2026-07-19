"
ADAPTER: implements the GcModelSource port using a Gt4HuggingFaceClient. The only class that references both the HuggingFace client and Gc domain objects -- it translates generic Hub results (config Dictionary, safetensors header) into GcModelConfig / GcSafetensorsFile / GcRepoManifest. Reads the optional token from ~/.secrets/huggingface-token.txt inside the image and injects it into the client.
"
Class {
	#name : 'GcHuggingFaceModelSource',
	#superclass : 'GcModelSource',
	#instVars : [
		'client',
		'repositoryId'
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

{ #category : 'fetching' }
GcHuggingFaceModelSource >> architectureFor: aRepoId [
	^ (self configFor: aRepoId) architecture
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> client [
	^ client
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> client: aClient [
	client := aClient
]

{ #category : 'fetching' }
GcHuggingFaceModelSource >> configFor: aRepoId [
	^ GcModelConfig fromDictionary: (client config: aRepoId)
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
