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

{ #category : 'fetching' }
GcModelSource >> configFor: aRepoId [
	"Answer a GcModelConfig for the given repository. Adapters implement."
	^ self subclassResponsibility
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
