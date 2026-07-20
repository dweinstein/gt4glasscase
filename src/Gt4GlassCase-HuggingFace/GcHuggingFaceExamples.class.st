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
GcHuggingFaceExamples >> liveCrossModelArchitectures [
	"Load the architecture of several real, different models and pair each with its repo. Vary the model_family axis of the hypercube."
	<gtExample>
	<noTest>
	| results |
	results := self smallPublicModels collect: [ :repo |
		repo -> (GcHuggingFaceModelSource forRepository: repo) architecture ].
	self assert: (results allSatisfy: [ :assoc | assoc value numLayers > 0 ]).
	^ results
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

{ #category : 'examples - live' }
GcHuggingFaceExamples >> liveTensorSampleStats [
	"End to end: fetch and decode a sampled slice of the smallest supported tensor of SmolLM2-135M via HTTP Range, and assert the Tier-1 statistics are sane. No weights downloaded wholesale (I5)."
	<gtExample>
	<noTest>
	| file tensor stats |
	file := self source safetensorsFileFor: self repositoryId file: 'model.safetensors'.
	tensor := (file tensors select: [ :t | t supportsSampling ]) detectMin: [ :t | t byteSize ].
	stats := tensor stats.
	self assert: stats sampleCount > 0.
	self assert: stats sampleCount <= GcTensorRef sampleElementCap.
	self assert: stats nanCount equals: 0.
	self assert: stats infCount equals: 0.
	self assert: stats mean isFinite.
	self assert: (stats min >= -10 and: [ stats max <= 10 ]).
	^ stats
]

{ #category : 'accessing' }
GcHuggingFaceExamples >> repositoryId [
	^ 'HuggingFaceTB/SmolLM2-135M'
]

{ #category : 'accessing' }
GcHuggingFaceExamples >> smallPublicModels [
	"Small, public, single-file models spanning architectures/naming schemes -- for cross-model comparison."
	^ #(
		'HuggingFaceTB/SmolLM2-135M'
		'Qwen/Qwen2.5-0.5B'
		'openai-community/gpt2'
		'EleutherAI/pythia-160m' )
]

{ #category : 'accessing' }
GcHuggingFaceExamples >> source [
	^ GcHuggingFaceModelSource forRepository: self repositoryId
]
