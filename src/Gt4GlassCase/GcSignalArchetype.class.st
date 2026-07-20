"
One DISTINCT KIND of layer within a GcSignalTower: the set of layer indices whose per-layer module signature (module paths with numeric indices wildcarded) is identical. A homogeneous transformer has exactly one archetype spanning all its layers; a hybrid model (e.g. linear-attention/SSM layers interleaved with full softmax-attention layers, some also MoE) has several. Carries its layer count and index range (for the block badge), a representative layer's tensors (the block drawn in detail), and classification of its attention sublayer (#split / #fused / #linear / #none, possibly hybrid = several) and MLP sublayer (#moe / #gated / #twoProj / #none) so each archetype block is labelled with what it ACTUALLY contains. Every module node's drill-in cohort is this archetype's own cross-layer tensors (a GcTensorGroup), never a cross-archetype union. Holds only GcTensorRefs (I5).
"
Class {
	#name : 'GcSignalArchetype',
	#superclass : 'Object',
	#instVars : [
		'tower',
		'layerIndices'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcSignalArchetype class >> tower: aTower layerIndices: aCollection [
	^ self new setTower: aTower layerIndices: aCollection asArray
]

{ #category : 'classification' }
GcSignalArchetype >> attentionKind [
	| linear softmax split |
	linear := self hasLinearAttention.
	softmax := self hasSoftmaxAttention.
	(linear and: [ softmax ]) ifTrue: [ ^ #hybrid ].
	linear ifTrue: [ ^ #linear ].
	softmax ifFalse: [ ^ self attentionTensors isEmpty ifTrue: [ #none ] ifFalse: [ #other ] ].
	split := self attentionTensors anySatisfy: [ :t | (self moduleLeafOf: t) = 'q_proj' ].
	^ split ifTrue: [ #split ] ifFalse: [ #fused ]
]

{ #category : 'classification' }
GcSignalArchetype >> attentionKindLabel [
	self attentionKind caseOf: {
		[ #linear ] -> [ ^ 'linear attn (SSM/GDN)' ].
		[ #hybrid ] -> [ ^ 'hybrid: softmax + linear (SSM)' ].
		[ #split ] -> [ ^ 'multi-head (split q/k/v)' ].
		[ #fused ] -> [ ^ 'fused qkv' ].
		[ #none ] -> [ ^ 'no attention' ] }
		otherwise: [ ^ 'attention' ]
]

{ #category : 'sublayers' }
GcSignalArchetype >> attentionTensors [
	"Representative-layer tensors whose container names an attention family (self_attn / attn / linear_attn / cross_attn)."
	^ self representativeTensors select: [ :t |
		(self containerOf: t) ifNil: [ false ] ifNotNil: [ :c | c includesSubstring: 'attn' ] ]
]

{ #category : 'printing' }
GcSignalArchetype >> badgeString [
	^ 'x ' , self layerCount printString , ' (' , self rangeCompact , ')'
]

{ #category : 'cohorts' }
GcSignalArchetype >> cohortForTensor: aTensor [
	"The archetype-scoped cohort of aTensor: same slot signature, restricted to this archetype's layers (never a cross-archetype union)."
	| sig set |
	sig := self flow signatureOf: aTensor.
	set := layerIndices asSet.
	^ self flow tensorGroup select: [ :t |
		(self flow signatureOf: t) = sig and: [ set includes: t layerIndex ] ]
]

{ #category : 'cohorts' }
GcSignalArchetype >> cohortMatchingName: aSubstring [
	"This archetype's tensors whose name contains aSubstring (e.g. 'expert') -- a GcTensorGroup for drill-in."
	| set |
	set := layerIndices asSet.
	^ self flow tensorGroup select: [ :t |
		(set includes: t layerIndex) and: [ t name includesSubstring: aSubstring ] ]
]

{ #category : 'parsing' }
GcSignalArchetype >> containerOf: aTensor [
	^ self flow containerOf: aTensor
]

{ #category : 'classification' }
GcSignalArchetype >> expertCount [
	"Number of routed experts: distinct per-expert indices, else the leading dim of a stacked experts tensor, else the config's expert count, else nil."
	| idxs stacked |
	idxs := (self mlpTensors collect: [ :t | t parsedName expertIndex ]) reject: [ :x | x isNil ].
	idxs notEmpty ifTrue: [ ^ (idxs asSet) size ].
	stacked := self mlpTensors
		detect: [ :t | (t name includesSubstring: 'experts') and: [ t dimensions size >= 3 ] ]
		ifNone: [ nil ].
	stacked ifNotNil: [ ^ stacked dimensions first ].
	self flow architecture ifNotNil: [ :a | a moeExperts ifNotNil: [ :n | ^ n ] ].
	^ nil
]

{ #category : 'accessing' }
GcSignalArchetype >> firstLayer [
	^ layerIndices isEmpty ifTrue: [ nil ] ifFalse: [ layerIndices first ]
]

{ #category : 'accessing' }
GcSignalArchetype >> flow [
	^ tower flow
]

{ #category : 'views' }
GcSignalArchetype >> gtLayersFor: aView [
	"The individual layers of this archetype; click one to inspect that layer's tensor cohort."
	<gtView>
	^ aView columnedList
		title: 'Layers';
		priority: 2;
		items: [ layerIndices ];
		column: 'Layer index' text: [ :i | i printString ];
		send: [ :i | tower tensors select: [ :t | t layerIndex = i ] ]
]

{ #category : 'views' }
GcSignalArchetype >> gtSublayersFor: aView [
	"What kind of layer is this? Its attention and MLP classification and counts."
	<gtView>
	^ aView columnedList
		title: 'Archetype';
		priority: 1;
		items: [ {
			'Layers' -> self badgeString.
			'Attention' -> self attentionKindLabel.
			'MLP' -> self mlpKindLabel.
			'Modules' -> (', ' join: ((self representativeTensors asArray collect: [ :t | self moduleLeafOf: t ]) asSet asSortedCollection)) } ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ]
]

{ #category : 'views' }
GcSignalArchetype >> gtTensorsFor: aView [
	"Every tensor across this archetype's layers (its cross-layer cohort)."
	<gtView>
	^ aView forward
		title: 'Tensors';
		priority: 3;
		object: [ self tensors ];
		view: #gtShapeTableFor:
]

{ #category : 'classification' }
GcSignalArchetype >> hasLinearAttention [
	"A linear-attention / state-space (SSM/GDN) sublayer: convolutional + state projections rather than softmax QK."
	^ self attentionTensors anySatisfy: [ :t | | c leaf |
		c := self containerOf: t.
		leaf := self moduleLeafOf: t.
		(c includesSubstring: 'linear')
			or: [ #('conv1d' 'in_proj_a' 'in_proj_b' 'in_proj_z' 'A_log' 'dt_bias') includes: leaf ] ]
]

{ #category : 'classification' }
GcSignalArchetype >> hasSharedExpert [
	^ self mlpTensors anySatisfy: [ :t | t name includesSubstring: 'shared_expert' ]
]

{ #category : 'classification' }
GcSignalArchetype >> hasSoftmaxAttention [
	"A classic softmax QK attention sublayer (split q/k/v or a fused qkv projection)."
	^ self attentionTensors anySatisfy: [ :t | | leaf |
		leaf := self moduleLeafOf: t.
		#('q_proj' 'k_proj' 'v_proj' 'query_key_value' 'c_attn' 'qkv') includes: leaf ]
]

{ #category : 'classification' }
GcSignalArchetype >> isMoE [
	^ self mlpTensors anySatisfy: [ :t | t name includesSubstring: 'experts' ]
]

{ #category : 'accessing' }
GcSignalArchetype >> layerCount [
	^ layerIndices size
]

{ #category : 'accessing' }
GcSignalArchetype >> layerIndices [
	^ layerIndices
]

{ #category : 'classification' }
GcSignalArchetype >> mlpKind [
	self isMoE ifTrue: [ ^ #moe ].
	self mlpTensors isEmpty ifTrue: [ ^ #none ].
	(self mlpTensors anySatisfy: [ :t | (self moduleLeafOf: t) includesSubstring: 'gate' ])
		ifTrue: [ ^ #gated ].
	^ #twoProj
]

{ #category : 'classification' }
GcSignalArchetype >> mlpKindLabel [
	self mlpKind caseOf: {
		[ #moe ] -> [ | n |
			n := self expertCount.
			^ 'MoE: ' , (n ifNil: [ 'N' ] ifNotNil: [ :x | x printString ]) , ' experts'
				, (self hasSharedExpert ifTrue: [ ' (+shared)' ] ifFalse: [ '' ]) ].
		[ #gated ] -> [ ^ 'gated (3-proj / SwiGLU-style)' ].
		[ #twoProj ] -> [ ^ '2-proj MLP' ].
		[ #none ] -> [ ^ 'no MLP' ] }
		otherwise: [ ^ 'MLP' ]
]

{ #category : 'sublayers' }
GcSignalArchetype >> mlpTensors [
	"Representative-layer tensors whose container names the feed-forward / MoE block."
	^ self representativeTensors select: [ :t |
		(self containerOf: t) ifNil: [ false ] ifNotNil: [ :c | (c includesSubstring: 'mlp') or: [ c includesSubstring: 'feed' ] ] ]
]

{ #category : 'parsing' }
GcSignalArchetype >> moduleLeafOf: aTensor [
	^ self flow moduleLeafOf: aTensor
]

{ #category : 'sublayers' }
GcSignalArchetype >> normTensors [
	"Layer-level standalone norms of the representative layer (not inside an attention/MLP container)."
	^ self representativeTensors select: [ :t |
		(self containerOf: t) isNil and: [ self flow looksLikeNormLeaf: (self moduleLeafOf: t) ] ]
]

{ #category : 'printing' }
GcSignalArchetype >> printOn: aStream [
	aStream
		nextPutAll: 'GcSignalArchetype(';
		nextPutAll: self layerCount printString;
		nextPutAll: 'L ';
		nextPutAll: self attentionKind asString;
		nextPut: $/;
		nextPutAll: self mlpKind asString;
		nextPut: $)
]

{ #category : 'printing' }
GcSignalArchetype >> rangeCompact [
	"A short human range of this archetype's layer indices, e.g. 'layers 0..28' or 'layers 0,3,7,11,...'."
	| lo hi |
	layerIndices isEmpty ifTrue: [ ^ 'layers -' ].
	lo := layerIndices first.
	hi := layerIndices last.
	(layerIndices size = (hi - lo + 1))
		ifTrue: [ ^ 'layers ' , lo printString , '..' , hi printString ].
	^ 'layers ' , (',' join: ((layerIndices first: (layerIndices size min: 4)) collect: [ :i | i printString ]))
		, (layerIndices size > 4 ifTrue: [ ',...' ] ifFalse: [ '' ])
]

{ #category : 'accessing' }
GcSignalArchetype >> representativeTensors [
	"The tensors of the archetype's lowest layer -- the block drawn in detail. All layers of the archetype share this structure."
	| rep |
	rep := self firstLayer.
	^ tower tensors select: [ :t | t layerIndex = rep ]
]

{ #category : 'initialization' }
GcSignalArchetype >> setTower: aTower layerIndices: anArray [
	tower := aTower.
	layerIndices := anArray asSortedCollection asArray
]

{ #category : 'accessing' }
GcSignalArchetype >> tensors [
	"Every tensor of every layer of this archetype (a GcTensorGroup, cross-layer cohort scope)."
	| set |
	set := layerIndices asSet.
	^ tower tensors select: [ :t | set includes: t layerIndex ]
]

{ #category : 'accessing' }
GcSignalArchetype >> tower [
	^ tower
]
