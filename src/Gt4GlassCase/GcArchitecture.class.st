"
Derived shape of a model: n_layers, n_heads, kv_heads, hidden size, MoE topology. The model's own internal regularity baseline.
"
Class {
	#name : 'GcArchitecture',
	#superclass : 'Object',
	#instVars : [
		'numLayers',
		'numHeads',
		'kvHeads',
		'hiddenSize',
		'moeExperts'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcArchitecture class >> fromConfig: aConfig [
	^ self new
		numLayers: aConfig numLayers;
		numHeads: aConfig numHeads;
		kvHeads: aConfig kvHeads;
		hiddenSize: aConfig hiddenSize;
		yourself
]

{ #category : 'dead weights' }
GcArchitecture >> deadWeightAnalysisOn: aTensorGroup [
	"Template-based; naming follows the Llama/Qwen family."
	| expected optional actualNames unreferenced missing matchedCount |
	expected := self expectedTensorNames.
	optional := self optionalTensorNames.
	actualNames := (aTensorGroup items collect: [ :each | each name ]) asSet.
	unreferenced := ((aTensorGroup items
		select: [ :each |
			(expected includes: each name) not
				and: [ (optional includes: each name) not ] ])
		asSortedCollection: [ :a :b | a name <= b name ]) asArray.
	missing := (expected select: [ :each | (actualNames includes: each) not ])
		asSortedCollection asArray.
	matchedCount := actualNames count: [ :each | (expected includes: each) or: [ optional includes: each ] ].
	^ Dictionary new
		at: #unreferenced put: unreferenced;
		at: #missing put: missing;
		at: #matchedCount put: matchedCount;
		at: #expectedCount put: expected size;
		yourself
]

{ #category : 'dead weights' }
GcArchitecture >> expectedTensorNames [
	| names prefix |
	names := Set new.
	(numLayers isNil or: [ numLayers = 0 ])
		ifTrue: [ ^ names ].
	names
		add: 'model.embed_tokens.weight';
		add: 'model.norm.weight'.
	0 to: numLayers - 1 do: [ :i |
		prefix := 'model.layers.' , i printString , '.'.
		names
			add: prefix , 'input_layernorm.weight';
			add: prefix , 'self_attn.q_proj.weight';
			add: prefix , 'self_attn.k_proj.weight';
			add: prefix , 'self_attn.v_proj.weight';
			add: prefix , 'self_attn.o_proj.weight';
			add: prefix , 'post_attention_layernorm.weight'.
		(moeExperts isNil or: [ moeExperts = 0 ])
			ifTrue: [
				names
					add: prefix , 'mlp.gate_proj.weight';
					add: prefix , 'mlp.up_proj.weight';
					add: prefix , 'mlp.down_proj.weight' ]
			ifFalse: [
				names add: prefix , 'mlp.gate.weight'.
				0 to: moeExperts - 1 do: [ :e | | expertPrefix |
					expertPrefix := prefix , 'mlp.experts.' , e printString , '.'.
					names
						add: expertPrefix , 'gate_proj.weight';
						add: expertPrefix , 'up_proj.weight';
						add: expertPrefix , 'down_proj.weight' ] ] ].
	^ names
]

{ #category : 'views' }
GcArchitecture >> gtOverviewFor: aView [
	"What shape is this model?"
	<gtView>
	^ aView columnedList
		title: 'Shape';
		priority: 1;
		items: [ self overviewFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | v displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'gt views' }
GcArchitecture >> gtSignalFlowFor: aView [
	"What shape of computation does this config imply? The canonical block diagram, inferred from config alone (no tensor names)."
	<gtView>
	^ aView forward
		title: 'Signal flow';
		priority: 2;
		object: [ GcSignalFlow fromArchitecture: self ];
		view: #gtSignalFlowFor:
]

{ #category : 'derived' }
GcArchitecture >> headDim [
	^ (hiddenSize notNil and: [ numHeads notNil and: [ numHeads > 0 ] ])
		ifTrue: [ hiddenSize // numHeads ]
		ifFalse: [ nil ]
]

{ #category : 'accessing' }
GcArchitecture >> hiddenSize [
	^ hiddenSize
]

{ #category : 'accessing' }
GcArchitecture >> hiddenSize: anInteger [
	hiddenSize := anInteger
]

{ #category : 'accessing' }
GcArchitecture >> kvHeads [
	^ kvHeads
]

{ #category : 'accessing' }
GcArchitecture >> kvHeads: anInteger [
	kvHeads := anInteger
]

{ #category : 'accessing' }
GcArchitecture >> moeExperts [
	^ moeExperts
]

{ #category : 'accessing' }
GcArchitecture >> moeExperts: anInteger [
	moeExperts := anInteger
]

{ #category : 'accessing' }
GcArchitecture >> numHeads [
	^ numHeads
]

{ #category : 'accessing' }
GcArchitecture >> numHeads: anInteger [
	numHeads := anInteger
]

{ #category : 'accessing' }
GcArchitecture >> numLayers [
	^ numLayers
]

{ #category : 'accessing' }
GcArchitecture >> numLayers: anInteger [
	numLayers := anInteger
]

{ #category : 'dead weights' }
GcArchitecture >> optionalTensorNames [
	| names prefix |
	names := Set new.
	numLayers isNil ifTrue: [ ^ names ].
	names add: 'lm_head.weight'.
	0 to: numLayers - 1 do: [ :i |
		prefix := 'model.layers.' , i printString , '.'.
		names
			add: prefix , 'self_attn.q_proj.bias';
			add: prefix , 'self_attn.k_proj.bias';
			add: prefix , 'self_attn.v_proj.bias';
			add: prefix , 'self_attn.q_norm.weight';
			add: prefix , 'self_attn.k_norm.weight' ].
	^ names
]

{ #category : 'views' }
GcArchitecture >> overviewFacets [
	^ {
		'Layers' -> numLayers.
		'Attention heads' -> numHeads.
		'KV heads (GQA)' -> kvHeads.
		'Hidden size' -> hiddenSize.
		'Head dim' -> self headDim.
		'MoE experts' -> moeExperts }
]

{ #category : 'printing' }
GcArchitecture >> printOn: aStream [
	aStream nextPutAll: 'GcArchitecture('.
	aStream print: numLayers.
	aStream nextPutAll: 'L x '.
	aStream print: hiddenSize.
	aStream nextPutAll: 'd)'
]
