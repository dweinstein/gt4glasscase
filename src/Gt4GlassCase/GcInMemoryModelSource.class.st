"
An in-memory GcModelSource adapter: an honest hexagonal test double that holds a GcModelConfig and a GcSafetensorsFile directly, with no transport. The core examples use it to exercise model-source comparison hermetically (no network). A source carrying both a config and a file is 'loaded'; one missing them models a not-yet-loaded source, so comparison views can be tested against 'not loaded' placeholders.
"
Class {
	#name : 'GcInMemoryModelSource',
	#superclass : 'GcModelSource',
	#instVars : [
		'label',
		'config',
		'safetensorsFile'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcInMemoryModelSource class >> named: aString config: aGcModelConfig safetensorsFile: aGcSafetensorsFile [
	^ self new
		label: aString;
		config: aGcModelConfig;
		safetensorsFile: aGcSafetensorsFile;
		yourself
]

{ #category : 'port' }
GcInMemoryModelSource >> architectureFor: aRepoId [
	^ config ifNotNil: [ :aConfig | aConfig architecture ]
]

{ #category : 'accessing' }
GcInMemoryModelSource >> config [
	^ config
]

{ #category : 'accessing' }
GcInMemoryModelSource >> config: aGcModelConfig [
	config := aGcModelConfig
]

{ #category : 'port' }
GcInMemoryModelSource >> configFor: aRepoId [
	^ config
]

{ #category : 'accessing' }
GcInMemoryModelSource >> label [
	^ label
]

{ #category : 'accessing' }
GcInMemoryModelSource >> label: aString [
	label := aString
]

{ #category : 'loading' }
GcInMemoryModelSource >> loadMetadata [
	"In-memory data is already resident; nothing to fetch."
	^ self
]

{ #category : 'cached access' }
GcInMemoryModelSource >> loadedConfig [
	"In-memory data is resident: the config is its own cache."
	^ config
]

{ #category : 'cached access' }
GcInMemoryModelSource >> loadedSafetensorsFile [
	^ safetensorsFile
]

{ #category : 'port' }
GcInMemoryModelSource >> manifestFor: aRepoId [
	"An in-memory source models a single materialized model; it exposes no file manifest."
	^ nil
]

{ #category : 'printing' }
GcInMemoryModelSource >> printOn: aStream [
	aStream nextPutAll: 'GcInMemoryModelSource('.
	aStream nextPutAll: (label ifNil: [ '?' ]).
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcInMemoryModelSource >> safetensorsFile [
	^ safetensorsFile
]

{ #category : 'accessing' }
GcInMemoryModelSource >> safetensorsFile: aGcSafetensorsFile [
	safetensorsFile := aGcSafetensorsFile
]

{ #category : 'port' }
GcInMemoryModelSource >> safetensorsFileFor: aRepoId file: aFileName [
	^ safetensorsFile
]
