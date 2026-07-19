"
Live, network-hitting end-to-end examples (each <gtExample> <noTest>, excluded from the hermetic test gate). They load a real small public model (SmolLM2-135M) through the GcHuggingFaceModelSource adapter to prove the pipeline works on real data. The hermetic GcExamples stay in the core package.
"
Class {
	#name : 'GcHuggingFaceExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase-HuggingFace',
	#package : 'Gt4GlassCase-HuggingFace'
}

{ #category : 'examples-live' }
GcHuggingFaceExamples >> liveArchitecture [
	<gtExample>
	<noTest>
	| arch |
	arch := self source architectureFor: self repositoryId.
	self assert: arch numLayers > 0.
	self assert: arch headDim equals: arch hiddenSize // arch numHeads.
	^ arch
]

{ #category : 'examples-live' }
GcHuggingFaceExamples >> liveConfig [
	"End to end: fetch a real config.json through the port and build a GcModelConfig."
	<gtExample>
	<noTest>
	| config |
	config := self source configFor: self repositoryId.
	self assert: config numLayers > 0.
	self assert: config hiddenSize > 0.
	self assert: config modelType isNil not.
	^ config
]

{ #category : 'examples-live' }
GcHuggingFaceExamples >> liveLayerConsistency [
	"Cross-check two independent real sources: the number of distinct transformer layers seen in the safetensors tensor names equals num_hidden_layers from config.json."
	<gtExample>
	<noTest>
	| source arch file group |
	source := self source.
	arch := source architectureFor: self repositoryId.
	file := source safetensorsFileFor: self repositoryId file: 'model.safetensors'.
	group := file tensorGroup.
	self assert: group layerIndices size equals: arch numLayers.
	^ group
]

{ #category : 'examples-live' }
GcHuggingFaceExamples >> liveSafetensorsHeader [
	"Fetch only the safetensors header via HTTP Range and materialize real GcTensorRefs -- no weights downloaded."
	<gtExample>
	<noTest>
	| file |
	file := self source safetensorsFileFor: self repositoryId file: 'model.safetensors'.
	self assert: file tensorCount > 50.
	self assert: file tensors first byteSize > 0.
	^ file
]

{ #category : 'examples-live' }
GcHuggingFaceExamples >> liveTensorGroupByModule [
	"Real tensors -> GcTensorGroup -> partition by parsed module name; report real parameter total."
	<gtExample>
	<noTest>
	| file group byModule |
	file := self source safetensorsFileFor: self repositoryId file: 'model.safetensors'.
	group := file tensorGroup.
	self assert: group totalParams > 50000000.
	byModule := group byModule.
	self assert: byModule size >= 4.
	^ byModule
]

{ #category : 'accessing' }
GcHuggingFaceExamples >> repositoryId [
	^ 'HuggingFaceTB/SmolLM2-135M'
]

{ #category : 'accessing' }
GcHuggingFaceExamples >> source [
	^ GcHuggingFaceModelSource forRepository: self repositoryId
]
