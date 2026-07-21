"
Shared 'what is this model' architectural lens. Any host that answers two hooks -- modelArchitecture (a GcArchitecture, config-derived shape) and modelTensorGroup (a GcTensorGroup over the safetensors header, or nil) -- gains the unified facets numLayers / numHeads / numKvHeads / headDim / hiddenSize / intermediateSize / vocabSize (from the architecture) and numParameters / modelDtype (from the checkpoint), plus a compact 'Model' <gtView> summarising them. Mixed into GcModelSource (structural/audit side, hooks read the no-network loaded* accessors) and GcGpt2Model (the running model, hooks read its already-loaded config + safetensors header), so both answer the same questions through the same lens. All facets are nil-safe: an unloaded host reports nil rather than erroring, honouring the no-network-in-render invariant.
"
Trait {
	#name : 'TGcModelArchitecture',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'facets - architecture' }
TGcModelArchitecture >> architectureFacets [
	"The unified 'what is this model' facets: config-derived shape fused with checkpoint-derived parameter count and dtype. Associations, for a compact table. Nil values render as '-'."
	^ {
		'Layers' -> self numLayers.
		'Attention heads' -> self numHeads.
		'KV heads (GQA)' -> self numKvHeads.
		'Head dim' -> self headDim.
		'Hidden size' -> self hiddenSize.
		'Intermediate size' -> self intermediateSize.
		'Vocab size' -> self vocabSize.
		'Parameters' -> self numParameters.
		'Dtype' -> self modelDtype }
]

{ #category : 'gt views' }
TGcModelArchitecture >> gtModelFactsFor: aView [
	"What is this model? The shared architecture summary -- config shape fused with checkpoint parameter count and dtype -- identical across every host that mixes in this trait."
	<gtView>
	^ aView columnedList
		title: 'Model';
		priority: 2;
		items: [ self architectureFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | v displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'facets - architecture' }
TGcModelArchitecture >> headDim [
	"Per-head dimension (hiddenSize // numHeads). Nil when not loaded."
	^ self modelArchitecture ifNotNil: [ :a | a headDim ]
]

{ #category : 'facets - architecture' }
TGcModelArchitecture >> hiddenSize [
	"Model (residual stream) width. Nil when not loaded."
	^ self modelArchitecture ifNotNil: [ :a | a hiddenSize ]
]

{ #category : 'facets - architecture' }
TGcModelArchitecture >> intermediateSize [
	"Feed-forward inner width. Nil when absent or not loaded."
	^ self modelArchitecture ifNotNil: [ :a | a intermediateSize ]
]

{ #category : 'facets - checkpoint' }
TGcModelArchitecture >> modelDtype [
	"The checkpoint's tensor dtype(s): a single symbol when homogeneous, otherwise the sorted distinct set. Nil when structure not loaded."
	^ self modelTensorGroup ifNotNil: [ :g | | dts |
		dts := ((g collect: [ :t | t dtype ]) asSet) asSortedCollection asArray.
		dts size = 1 ifTrue: [ dts first ] ifFalse: [ dts ] ]
]

{ #category : 'facets - architecture' }
TGcModelArchitecture >> numHeads [
	"Number of attention (query) heads. Nil when not loaded."
	^ self modelArchitecture ifNotNil: [ :a | a numHeads ]
]

{ #category : 'facets - architecture' }
TGcModelArchitecture >> numKvHeads [
	"Number of key/value heads (GQA); equals numHeads for standard multi-head attention. Nil when not loaded."
	^ self modelArchitecture ifNotNil: [ :a | a kvHeads ifNil: [ a numHeads ] ]
]

{ #category : 'facets - architecture' }
TGcModelArchitecture >> numLayers [
	"Number of transformer layers, from the config-derived architecture. Nil when not loaded."
	^ self modelArchitecture ifNotNil: [ :a | a numLayers ]
]

{ #category : 'facets - checkpoint' }
TGcModelArchitecture >> numParameters [
	"Total parameter count from the safetensors header (shape products; no weight decode). Nil when the checkpoint structure is not loaded."
	^ self modelTensorGroup ifNotNil: [ :g | g totalParams ]
]

{ #category : 'facets - architecture' }
TGcModelArchitecture >> vocabSize [
	"Vocabulary size. Nil when not loaded."
	^ self modelArchitecture ifNotNil: [ :a | a vocabSize ]
]
