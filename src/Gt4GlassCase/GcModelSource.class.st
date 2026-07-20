"
PORT (hexagonal architecture): the interface Glass Case depends on to obtain model data, expressed purely in Gc domain objects. Subclasses (adapters) fetch from a concrete source -- HuggingFace, a local safetensors directory, S3 -- and translate. The core domain never references any transport, so sources are swappable without touching it. configFor:/architectureFor:/safetensorsFileFor:file:/manifestFor: are subclassResponsibility.
"
Class {
	#name : 'GcModelSource',
	#superclass : 'Object',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'fetching' }
GcModelSource >> architectureFor: aRepoId [
	"Answer a GcArchitecture for the given repository. Adapters implement."
	^ self subclassResponsibility
]

{ #category : 'comparing' }
GcModelSource >> compareWith: anotherSource [
	"Answer a two-member GcModelSourceGroup comparing the receiver with anotherSource. The group's lineage is stamped with the #compareWith: operation (I3), so how it was made is never lost. Available on the port, so every adapter is comparable."
	| group |
	group := GcModelSourceGroup withAll: { self. anotherSource }.
	group derivation: (GcDerivation new
		operation: #compareWith:;
		parameters: (Dictionary new at: #with put: anotherSource; yourself);
		yourself).
	^ group
]

{ #category : 'fetching' }
GcModelSource >> configFor: aRepoId [
	"Answer a GcModelConfig for the given repository. Adapters implement."
	^ self subclassResponsibility
]

{ #category : 'cached access' }
GcModelSource >> isMetadataLoaded [
	"True when both config and safetensors header are cached, so comparison views can read them without network."
	^ self loadedConfig notNil and: [ self loadedSafetensorsFile notNil ]
]

{ #category : 'accessing' }
GcModelSource >> label [
	"A short human label used as a column header when this source is compared with others. Adapters override with something salient (repo id, given name)."
	^ self printString
]

{ #category : 'loading' }
GcModelSource >> loadMetadata [
	"Fetch and cache config.json + the safetensors header for this source (bounded network). Adapters implement. NEVER call this from a <gtView> render block."
	^ self subclassResponsibility
]

{ #category : 'cached access' }
GcModelSource >> loadedArchitecture [
	"The GcArchitecture derived from the cached config, or nil if not loaded. No network."
	^ self loadedConfig ifNotNil: [ :aConfig | aConfig architecture ]
]

{ #category : 'cached access' }
GcModelSource >> loadedConfig [
	"The already-fetched GcModelConfig, or nil if metadata has not been loaded yet. NEVER triggers network -- safe to call from a render block. Adapters that cache override this."
	^ nil
]

{ #category : 'cached access' }
GcModelSource >> loadedSafetensorsFile [
	"The already-fetched GcSafetensorsFile, or nil if the header has not been loaded yet. NEVER triggers network. Adapters that cache override this."
	^ nil
]

{ #category : 'cached access' }
GcModelSource >> loadedTensorGroup [
	"A GcTensorGroup over the cached safetensors header, or nil if not loaded. No network."
	^ self loadedSafetensorsFile ifNotNil: [ :aFile | aFile tensorGroup ]
]

{ #category : 'fetching' }
GcModelSource >> manifestFor: aRepoId [
	"Answer a GcRepoManifest of the repository's files. Adapters implement."
	^ self subclassResponsibility
]

{ #category : 'fetching' }
GcModelSource >> safetensorsFileFor: aRepoId file: aFileName [
	"Answer a GcSafetensorsFile (header parsed into GcTensorRefs) without downloading weights. Adapters implement."
	^ self subclassResponsibility
]
