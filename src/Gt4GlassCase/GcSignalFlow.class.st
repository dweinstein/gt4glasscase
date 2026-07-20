"
The shape of the computation a checkpoint performs, as a control-system / signal-flow block diagram derived ENTIRELY from metadata (tensor names + config), never from weight values.

Two constructions:
- fromTensorGroup: / fromTensorGroup:architecture: -- authoritative: the per-layer block wiring is derived from the module names actually present in layer 0's cohort (fused vs split attention, gated vs 2-proj MLP, norm placement), and every module node carries its real cross-layer cohort as a GcTensorGroup.
- fromArchitecture: -- fallback when only a config-derived GcArchitecture is available (no tensor names): draws the canonical llama-style wiring implied by the config, marked as inferred.

The gtSignalFlowFor: Mondrian view draws token ids -> embedding -> one representative transformer block (annotated x N layers) -> final norm -> lm_head -> logits, with the residual/skip bypass edges around the attention and MLP sublayers drawn as visually distinct (dashed, coloured) edges. I hold my derived nodes as GcSignalFlowNodes; I never fetch (I5) -- I read only already-loaded state.
"
Class {
	#name : 'GcSignalFlow',
	#superclass : 'Object',
	#instVars : [
		'tensorGroup',
		'architecture',
		'inferred',
		'attentionFused',
		'mlpGated',
		'nodesCache'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcSignalFlow class >> fromArchitecture: anArchitecture [
	"Fallback: no tensor names available -- draw the canonical llama-style wiring the config implies, marked inferred."
	^ self new setTensorGroup: nil architecture: anArchitecture inferred: true
]

{ #category : 'instance creation' }
GcSignalFlow class >> fromTensorGroup: aTensorGroup [
	"Authoritative: derive the block wiring from the tensor names in aTensorGroup."
	^ self new setTensorGroup: aTensorGroup architecture: nil inferred: false
]

{ #category : 'instance creation' }
GcSignalFlow class >> fromTensorGroup: aTensorGroup architecture: anArchitecture [
	"Authoritative wiring from tensor names, enriched with head/hidden facts from anArchitecture (may be nil)."
	^ self new setTensorGroup: aTensorGroup architecture: anArchitecture inferred: false
]

{ #category : 'accessing' }
GcSignalFlow >> architecture [
	^ architecture
]

{ #category : 'testing' }
GcSignalFlow >> attentionFused [
	self nodes.
	^ attentionFused == true
]

{ #category : 'derivation - facts' }
GcSignalFlow >> attentionHeadNote [
	| nh kv |
	nh := architecture ifNotNil: [ :a | a numHeads ].
	kv := architecture ifNotNil: [ :a | a kvHeads ].
	(nh notNil and: [ kv notNil ]) ifTrue: [
		^ nh = kv
			ifTrue: [ nh printString , ' heads (MHA)' ]
			ifFalse: [ nh printString , ' Q / ' , kv printString , ' KV heads (GQA)' ] ].
	nh notNil ifTrue: [ ^ nh printString , ' heads' ].
	^ attentionFused == true ifTrue: [ 'fused qkv' ] ifFalse: [ 'multi-head (split q/k/v)' ]
]

{ #category : 'rendering' }
GcSignalFlow >> backgroundColorForKind: aKind [
	aKind = #embedding ifTrue: [ ^ Color blue alpha: 0.12 ].
	aKind = #head ifTrue: [ ^ Color blue alpha: 0.12 ].
	aKind = #attention ifTrue: [ ^ Color green alpha: 0.14 ].
	aKind = #mlp ifTrue: [ ^ Color orange alpha: 0.16 ].
	aKind = #norm ifTrue: [ ^ Color gray alpha: 0.14 ].
	aKind = #finalNorm ifTrue: [ ^ Color gray alpha: 0.18 ].
	aKind = #add ifTrue: [ ^ Color red alpha: 0.12 ].
	aKind = #legend ifTrue: [ ^ Color purple alpha: 0.10 ].
	^ Color white
]

{ #category : 'derivation' }
GcSignalFlow >> buildFromTensors [
	"Derive the block wiring from the module names present in the representative layer's cohort, then wire the global chain and the residual bypass edges."
	| nodes l0 attn mlp norms attnReps attnOutRep attnInReps mlpReps mlpOutRep mlpInReps preRep postRep embedT finalT headT tied legend tokens embed preNorm attnInNodes attnOut attnAdd postNorm mlpInNodes mlpOut mlpAdd finalNorm head logits attnEntry mlpEntry |
	nodes := OrderedCollection new.
	l0 := self layerZeroTensors.
	attn := l0 select: [ :t | | c | c := self containerOf: t. c notNil and: [ c includesSubstring: 'attn' ] ].
	mlp := l0 select: [ :t | | c | c := self containerOf: t. c notNil and: [ (c includesSubstring: 'mlp') or: [ c includesSubstring: 'feed' ] ] ].
	norms := l0 select: [ :t | (self containerOf: t) isNil and: [ self looksLikeNormLeaf: (self moduleLeafOf: t) ] ].
	attnReps := self uniqueLeafRepsFrom: attn.
	attnOutRep := attnReps detect: [ :t | self isAttentionOutputLeaf: (self moduleLeafOf: t) ] ifNone: [ attnReps isEmpty ifTrue: [ nil ] ifFalse: [ attnReps last ] ].
	attnInReps := attnReps reject: [ :t | t == attnOutRep ].
	attentionFused := attnInReps size <= 1.
	mlpReps := self uniqueLeafRepsFrom: mlp.
	mlpOutRep := mlpReps detect: [ :t | self isMlpOutputLeaf: (self moduleLeafOf: t) ] ifNone: [ mlpReps isEmpty ifTrue: [ nil ] ifFalse: [ mlpReps last ] ].
	mlpInReps := mlpReps reject: [ :t | t == mlpOutRep ].
	mlpGated := (mlpInReps anySatisfy: [ :t | (self moduleLeafOf: t) includesSubstring: 'gate' ]) or: [ mlpInReps size >= 2 ].
	preRep := norms detect: [ :t | | m | m := self moduleLeafOf: t. (m includesSubstring: 'input') or: [ m includesSubstring: '_1' ] ] ifNone: [ norms isEmpty ifTrue: [ nil ] ifFalse: [ norms first ] ].
	postRep := norms detect: [ :t | | m | m := self moduleLeafOf: t. (m includesSubstring: 'post') or: [ m includesSubstring: '_2' ] ] ifNone: [ norms size >= 2 ifTrue: [ (norms reject: [ :x | x == preRep ]) first ] ifFalse: [ nil ] ].
	embedT := self embeddingTensor.
	finalT := self finalNormTensor.
	headT := self lmHeadTensor.
	tied := headT isNil.
	legend := self nodeLabeled: self shortStyleLabel kind: #legend payload: nil annotation: self computeStyleLabel.
	tokens := self nodeLabeled: 'token ids' kind: #tokens payload: nil annotation: nil.
	nodes add: legend; add: tokens.
	legend addForward: tokens.
	embedT ifNotNil: [
		embed := self nodeLabeled: (self moduleLeafOf: embedT) kind: #embedding payload: (self cohortFor: embedT) annotation: (self embeddingAnnotation: embedT).
		nodes add: embed.
		tokens addForward: embed ].
	preRep ifNotNil: [
		preNorm := self nodeLabeled: (self moduleLeafOf: preRep) kind: #norm payload: (self cohortFor: preRep) annotation: 'pre-attention norm'.
		preNorm badge: 'x ' , self layerCountString , ' layers'.
		nodes add: preNorm.
		embed ifNotNil: [ embed addForward: preNorm ] ].
	(embed isNil and: [ preNorm notNil ]) ifTrue: [ tokens addForward: preNorm ].
	attnEntry := preNorm ifNil: [ embed ifNil: [ tokens ] ].
	attnInNodes := attnInReps collect: [ :t | self nodeLabeled: (self moduleLeafOf: t) kind: #attention payload: (self cohortFor: t) annotation: (attentionFused ifTrue: [ 'fused qkv' ] ifFalse: [ nil ]) ].
	attnInNodes do: [ :n | nodes add: n. attnEntry ifNotNil: [ attnEntry addForward: n ] ].
	attnOutRep ifNotNil: [
		attnOut := self nodeLabeled: (self moduleLeafOf: attnOutRep) kind: #attention payload: (self cohortFor: attnOutRep) annotation: self attentionHeadNote.
		nodes add: attnOut.
		attnInNodes do: [ :n | n addForward: attnOut ] ].
	attnAdd := self nodeLabeled: '(+) residual' kind: #add payload: nil annotation: 'attention add'.
	nodes add: attnAdd.
	(attnOut ifNil: [ attnInNodes isEmpty ifTrue: [ attnEntry ] ifFalse: [ attnInNodes last ] ]) ifNotNil: [ :src | src addForward: attnAdd ].
	attnEntry ifNotNil: [ attnEntry addResidual: attnAdd ].
	postRep ifNotNil: [
		postNorm := self nodeLabeled: (self moduleLeafOf: postRep) kind: #norm payload: (self cohortFor: postRep) annotation: 'pre-MLP norm'.
		nodes add: postNorm.
		attnAdd addForward: postNorm ].
	mlpEntry := postNorm ifNil: [ attnAdd ].
	mlpInNodes := mlpInReps collect: [ :t | self nodeLabeled: (self moduleLeafOf: t) kind: #mlp payload: (self cohortFor: t) annotation: (self mlpAnnotation: t) ].
	mlpInNodes do: [ :n | nodes add: n. mlpEntry addForward: n ].
	mlpOutRep ifNotNil: [
		mlpOut := self nodeLabeled: (self moduleLeafOf: mlpOutRep) kind: #mlp payload: (self cohortFor: mlpOutRep) annotation: self mlpStyleNote.
		nodes add: mlpOut.
		mlpInNodes do: [ :n | n addForward: mlpOut ] ].
	mlpAdd := self nodeLabeled: '(+) residual' kind: #add payload: nil annotation: 'MLP add'.
	nodes add: mlpAdd.
	(mlpOut ifNil: [ mlpInNodes isEmpty ifTrue: [ mlpEntry ] ifFalse: [ mlpInNodes last ] ]) ifNotNil: [ :src | src addForward: mlpAdd ].
	attnAdd addResidual: mlpAdd.
	finalT ifNotNil: [
		finalNorm := self nodeLabeled: 'final norm' kind: #finalNorm payload: (self cohortFor: finalT) annotation: (self moduleLeafOf: finalT).
		nodes add: finalNorm.
		mlpAdd addForward: finalNorm ].
	head := self nodeLabeled: (tied ifTrue: [ 'lm_head (tied)' ] ifFalse: [ self moduleLeafOf: headT ]) kind: #head payload: (tied ifTrue: [ embedT ifNotNil: [ self cohortFor: embedT ] ] ifFalse: [ self cohortFor: headT ]) annotation: self headAnnotation.
	nodes add: head.
	(finalNorm ifNil: [ mlpAdd ]) addForward: head.
	logits := self nodeLabeled: 'logits' kind: #output payload: nil annotation: nil.
	nodes add: logits.
	head addForward: logits.
	^ nodes
]

{ #category : 'derivation' }
GcSignalFlow >> buildInferredNodes [
	"No tensor names available: draw the canonical llama-style block wiring the config implies, with the config facet as every node's payload. Marked inferred."
	| arch nodes legend tokens embed preNorm q k v attnOut attnAdd postNorm gate up mlpOut mlpAdd finalNorm head logits |
	arch := architecture.
	attentionFused := false.
	mlpGated := true.
	nodes := OrderedCollection new.
	legend := self nodeLabeled: 'inferred (config)' kind: #legend payload: arch annotation: self computeStyleLabel.
	tokens := self nodeLabeled: 'token ids' kind: #tokens payload: nil annotation: nil.
	embed := self nodeLabeled: 'embed_tokens' kind: #embedding payload: arch annotation: 'vocab x hidden'.
	preNorm := self nodeLabeled: 'input_layernorm' kind: #norm payload: arch annotation: 'pre-attention norm'.
	preNorm badge: 'x ' , self layerCountString , ' layers'.
	q := self nodeLabeled: 'q_proj' kind: #attention payload: arch annotation: nil.
	k := self nodeLabeled: 'k_proj' kind: #attention payload: arch annotation: nil.
	v := self nodeLabeled: 'v_proj' kind: #attention payload: arch annotation: nil.
	attnOut := self nodeLabeled: 'o_proj' kind: #attention payload: arch annotation: self attentionHeadNote.
	attnAdd := self nodeLabeled: '(+) residual' kind: #add payload: nil annotation: 'attention add'.
	postNorm := self nodeLabeled: 'post_attention_layernorm' kind: #norm payload: arch annotation: 'pre-MLP norm'.
	gate := self nodeLabeled: 'gate_proj' kind: #mlp payload: arch annotation: nil.
	up := self nodeLabeled: 'up_proj' kind: #mlp payload: arch annotation: nil.
	mlpOut := self nodeLabeled: 'down_proj' kind: #mlp payload: arch annotation: 'gated (3-proj / SwiGLU-style)'.
	mlpAdd := self nodeLabeled: '(+) residual' kind: #add payload: nil annotation: 'MLP add'.
	finalNorm := self nodeLabeled: 'final norm' kind: #finalNorm payload: arch annotation: 'model.norm'.
	head := self nodeLabeled: 'lm_head' kind: #head payload: arch annotation: self headAnnotation.
	logits := self nodeLabeled: 'logits' kind: #output payload: nil annotation: nil.
	nodes addAll: { legend. tokens. embed. preNorm. q. k. v. attnOut. attnAdd. postNorm. gate. up. mlpOut. mlpAdd. finalNorm. head. logits }.
	legend addForward: tokens.
	tokens addForward: embed.
	embed addForward: preNorm.
	preNorm addForward: q; addForward: k; addForward: v.
	q addForward: attnOut.
	k addForward: attnOut.
	v addForward: attnOut.
	attnOut addForward: attnAdd.
	preNorm addResidual: attnAdd.
	attnAdd addForward: postNorm.
	postNorm addForward: gate; addForward: up.
	gate addForward: mlpOut.
	up addForward: mlpOut.
	mlpOut addForward: mlpAdd.
	attnAdd addResidual: mlpAdd.
	mlpAdd addForward: finalNorm.
	finalNorm addForward: head.
	head addForward: logits.
	^ nodes
]

{ #category : 'derivation' }
GcSignalFlow >> buildNodes [
	^ self hasTensors
		ifTrue: [ self buildFromTensors ]
		ifFalse: [ self buildInferredNodes ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> cohortFor: aTensor [
	"The GcTensorGroup of every tensor in this checkpoint that occupies the same slot as aTensor across all layers."
	| sig |
	sig := self signatureOf: aTensor.
	^ tensorGroup select: [ :t | (self signatureOf: t) = sig ]
]

{ #category : 'derivation - facts' }
GcSignalFlow >> computeStyleLabel [
	"Reads the fused/gated ivars directly so it is safe to call while nodes are being built."
	self isInferred ifTrue: [ ^ 'inferred from config (canonical llama-style)' ].
	^ self modelStyleName , ' | '
		, (attentionFused == true ifTrue: [ 'fused attn' ] ifFalse: [ 'split attn' ]) , ' | '
		, (mlpGated == true ifTrue: [ 'gated MLP' ] ifFalse: [ '2-proj MLP' ])
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> containerOf: aTensor [
	"The sublayer container token (self_attn / attn / mlp / ...) for a per-layer tensor, or nil for a layer-level standalone (a norm)."
	| parts pos |
	parts := self partsOf: aTensor.
	pos := self layerPositionIn: parts.
	pos = 0 ifTrue: [ ^ nil ].
	^ (parts size - pos) >= 3
		ifTrue: [ parts at: pos + 1 ]
		ifFalse: [ nil ]
]

{ #category : 'rendering' }
GcSignalFlow >> elementForNode: aNode [
	| box |
	box := BlElement new
		layout: BlLinearLayout vertical;
		padding: (BlInsets all: 6);
		margin: (BlInsets all: 3);
		background: (self backgroundColorForKind: aNode kind);
		border: (BlBorder paint: (Color gray alpha: 0.6) width: 1);
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		yourself.
	box addChild: (BlTextElement new text: aNode label asRopedText).
	aNode annotation ifNotNil: [ :ann |
		box addChild: (BlTextElement new text: (ann asRopedText foreground: Color gray)) ].
	aNode badge ifNotNil: [ :b |
		box addChild: (BlTextElement new text: (b asRopedText foreground: Color blue)) ].
	^ box
]

{ #category : 'derivation - facts' }
GcSignalFlow >> embeddingAnnotation: aTensor [
	| d |
	d := aTensor dimensions.
	^ d size >= 2
		ifTrue: [ d first printString , ' x ' , d last printString , ' (vocab x hidden)' ]
		ifFalse: [ 'vocab x hidden' ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> embeddingTensor [
	^ tensorGroup detect: [ :t | | m |
		t layerIndex isNil and: [
			m := self moduleLeafOf: t.
			(m includesSubstring: 'embed') or: [ m = 'wte' ] ] ]
		ifNone: [ nil ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> finalNormTensor [
	^ tensorGroup detect: [ :t | | m |
		t layerIndex isNil and: [
			m := self moduleLeafOf: t.
			((m includesSubstring: 'norm') or: [ m includesSubstring: 'ln' ]) and: [ (m includesSubstring: 'embed') not ] ] ]
		ifNone: [ nil ]
]

{ #category : 'gt views' }
GcSignalFlow >> gtSignalFlowFor: aView [
	"What is the shape of the computation this checkpoint performs? A control-system block diagram: token ids -> embedding -> one detailed transformer block (x N layers) -> final norm -> lm_head -> logits, with the residual/skip bypass edges (dashed orange) drawn around the attention and MLP sublayers."
	<gtView>
	^ aView mondrian
		title: 'Signal flow';
		priority: 2;
		painting: [ :m | self paintSignalFlowOn: m ]
]

{ #category : 'gt views' }
GcSignalFlow >> gtStagesFor: aView [
	"The derived blocks in signal order -- a textual read of the same diagram; click a stage to inspect its cohort."
	<gtView>
	^ aView columnedList
		title: 'Stages';
		priority: 3;
		items: [ self nodes ];
		column: 'Stage' text: [ :n | n label ];
		column: 'Kind' text: [ :n | n kind asString ];
		column: 'Detail' text: [ :n | n annotation ifNil: [ '' ] ];
		send: [ :n | n ]
]

{ #category : 'testing' }
GcSignalFlow >> hasTensors [
	^ tensorGroup notNil and: [ tensorGroup notEmpty ]
]

{ #category : 'derivation - facts' }
GcSignalFlow >> headAnnotation [
	| v h |
	v := self vocabSizeValue.
	h := self hiddenSizeValue.
	(v notNil and: [ h notNil ]) ifTrue: [ ^ h printString , ' x ' , v printString , ' (hidden x vocab)' ].
	^ 'hidden x vocab'
]

{ #category : 'derivation - facts' }
GcSignalFlow >> hiddenSizeValue [
	architecture ifNotNil: [ :a | a hiddenSize ifNotNil: [ :h | ^ h ] ].
	self hasTensors ifFalse: [ ^ nil ].
	^ self embeddingTensor
		ifNil: [ nil ]
		ifNotNil: [ :e | | d | d := e dimensions. d isEmpty ifTrue: [ nil ] ifFalse: [ d last ] ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> isAttentionOutputLeaf: aLeaf [
	^ #('o_proj' 'c_proj' 'out_proj' 'dense' 'wo' 'proj') includes: aLeaf
]

{ #category : 'testing' }
GcSignalFlow >> isInferred [
	^ inferred == true
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> isMlpOutputLeaf: aLeaf [
	^ #('down_proj' 'c_proj' 'dense_4h_to_h' 'fc2' 'w2' 'proj' 'wo') includes: aLeaf
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> isNumericString: aString [
	^ aString notEmpty and: [ aString allSatisfy: [ :c | c isDigit ] ]
]

{ #category : 'testing' }
GcSignalFlow >> isTiedEmbeddings [
	^ self hasTensors and: [ self lmHeadTensor isNil ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> isWeightTensor: aTensor [
	^ aTensor name endsWith: '.weight'
]

{ #category : 'derivation - facts' }
GcSignalFlow >> layerCountString [
	| n |
	n := self hasTensors
		ifTrue: [ tensorGroup layerIndices size ]
		ifFalse: [ architecture ifNotNil: [ :a | a numLayers ] ].
	^ n ifNil: [ '?' ] ifNotNil: [ n printString ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> layerPositionIn: parts [
	"1-based index of the numeric layer token in parts, or 0 if none."
	^ parts findFirst: [ :p | self isNumericString: p ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> layerZeroTensors [
	"The tensors of the representative (lowest-index) transformer layer -- the block we draw in detail."
	| rep |
	rep := self representativeLayerIndex.
	rep isNil ifTrue: [ ^ tensorGroup select: [ :t | false ] ].
	^ tensorGroup select: [ :t | t layerIndex = rep ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> lmHeadTensor [
	^ tensorGroup detect: [ :t | | m |
		m := self moduleLeafOf: t.
		(m = 'lm_head') or: [ (m = 'embed_out') or: [ t name includesSubstring: 'lm_head' ] ] ]
		ifNone: [ nil ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> looksLikeNormLeaf: aLeaf [
	aLeaf isNil ifTrue: [ ^ false ].
	^ (aLeaf includesSubstring: 'norm') or: [ aLeaf includesSubstring: 'ln' ]
]

{ #category : 'derivation - facts' }
GcSignalFlow >> mlpAnnotation: aTensor [
	| d h inter |
	d := aTensor dimensions.
	d isEmpty ifTrue: [ ^ nil ].
	h := self hiddenSizeValue.
	inter := (h notNil and: [ d includes: h ])
		ifTrue: [ (d reject: [ :x | x = h ]) ifEmpty: [ d last ] ifNotEmpty: [ :r | r first ] ]
		ifFalse: [ d max ].
	^ 'intermediate ' , inter printString
]

{ #category : 'testing' }
GcSignalFlow >> mlpGated [
	self nodes.
	^ mlpGated == true
]

{ #category : 'derivation - facts' }
GcSignalFlow >> mlpStyleNote [
	^ mlpGated == true
		ifTrue: [ 'gated (3-proj / SwiGLU-style)' ]
		ifFalse: [ '2-proj MLP' ]
]

{ #category : 'derivation - facts' }
GcSignalFlow >> modelStyleName [
	| leaves |
	self hasTensors ifFalse: [ ^ 'transformer' ].
	leaves := (self layerZeroTensors asArray collect: [ :t | self moduleLeafOf: t ]) asSet.
	(leaves includes: 'c_attn') ifTrue: [ ^ 'gpt2-style' ].
	(leaves includes: 'query_key_value') ifTrue: [ ^ 'gpt-neox-style' ].
	(leaves includes: 'q_proj') ifTrue: [ ^ 'llama-style' ].
	^ 'transformer'
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> moduleLeafOf: aTensor [
	"The module leaf name (q_proj / c_attn / gate_proj / input_layernorm / wte / lm_head / ...)."
	| parts pos after |
	parts := self partsOf: aTensor.
	pos := self layerPositionIn: parts.
	pos = 0 ifTrue: [ ^ aTensor module ].
	after := parts size - pos.
	after = 2 ifTrue: [ ^ parts at: pos + 1 ].
	after >= 3 ifTrue: [ ^ parts at: parts size - 1 ].
	^ aTensor module
]

{ #category : 'derivation' }
GcSignalFlow >> nodeLabeled: aLabel kind: aKind payload: aPayload annotation: anAnnotation [
	^ GcSignalFlowNode new
		label: aLabel;
		kind: aKind;
		payload: aPayload;
		annotation: anAnnotation;
		yourself
]

{ #category : 'accessing' }
GcSignalFlow >> nodeLabels [
	^ self nodes collect: [ :n | n label ]
]

{ #category : 'accessing' }
GcSignalFlow >> nodes [
	"The derived block nodes, built once. Reads only already-loaded state -- no network (I5)."
	^ nodesCache ifNil: [ nodesCache := self buildNodes ]
]

{ #category : 'rendering' }
GcSignalFlow >> paintSignalFlowOn: aMondrian [
	"Paint the block nodes, the forward signal path (solid), then the residual bypass edges (dashed orange, anchored top-to-top so they arc over the sublayer they skip)."
	aMondrian nodes
		stencil: [ :node | self elementForNode: node ];
		with: self nodes.
	aMondrian edges
		connectToAll: [ :node | node forwardTargets ].
	aMondrian edges
		fromCenterTop;
		toCenterTop;
		stencil: [ :e |
			BlLineElement new
				border: (BlBorder builder paint: Color orange; width: 2; dashed; build);
				zIndex: -1;
				yourself ];
		connectToAll: [ :node | node residualTargets ].
	aMondrian layout horizontalDominanceTree
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> partsOf: aTensor [
	^ aTensor name substrings: '.'
]

{ #category : 'printing' }
GcSignalFlow >> printOn: aStream [
	aStream nextPutAll: 'GcSignalFlow('.
	aStream nextPutAll: (self hasTensors ifTrue: [ 'tensors' ] ifFalse: [ 'inferred' ]).
	aStream nextPut: $)
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> representativeLayerIndex [
	| idx |
	idx := tensorGroup layerIndices.
	^ idx isEmpty ifTrue: [ nil ] ifFalse: [ idx first ]
]

{ #category : 'accessing' }
GcSignalFlow >> residualEdgeCount [
	^ self nodes inject: 0 into: [ :sum :n | sum + n residualTargets size ]
]

{ #category : 'initialization' }
GcSignalFlow >> setTensorGroup: aTensorGroup architecture: anArchitecture inferred: aBoolean [
	tensorGroup := aTensorGroup.
	architecture := anArchitecture.
	inferred := aBoolean
]

{ #category : 'derivation - facts' }
GcSignalFlow >> shortStyleLabel [
	^ self isInferred
		ifTrue: [ 'inferred (config)' ]
		ifFalse: [ self modelStyleName ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> signatureOf: aTensor [
	"A cohort signature: the tensor path with every numeric part (the layer index, any expert index) wildcarded to #, so tensors in the same slot across layers share a signature."
	| parts |
	parts := self partsOf: aTensor.
	^ '.' join: (parts collect: [ :p | (self isNumericString: p) ifTrue: [ '#' ] ifFalse: [ p ] ])
]

{ #category : 'accessing' }
GcSignalFlow >> styleLabel [
	self nodes.
	^ self computeStyleLabel
]

{ #category : 'accessing' }
GcSignalFlow >> tensorGroup [
	^ tensorGroup
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> uniqueLeafRepsFrom: aGroup [
	"One representative tensor per distinct module leaf in aGroup, in first-seen order, preferring the .weight tensor so cohorts and dimension annotations are deterministic (matching the codebase's module+role cohort convention)."
	| byLeaf order |
	byLeaf := Dictionary new.
	order := OrderedCollection new.
	aGroup do: [ :t | | leaf existing |
		leaf := self moduleLeafOf: t.
		existing := byLeaf at: leaf ifAbsent: [ nil ].
		existing isNil
			ifTrue: [ byLeaf at: leaf put: t. order add: leaf ]
			ifFalse: [ ((self isWeightTensor: t) and: [ (self isWeightTensor: existing) not ]) ifTrue: [ byLeaf at: leaf put: t ] ] ].
	^ order collect: [ :leaf | byLeaf at: leaf ]
]

{ #category : 'derivation - facts' }
GcSignalFlow >> vocabSizeValue [
	self hasTensors ifFalse: [ ^ nil ].
	^ self embeddingTensor
		ifNil: [ nil ]
		ifNotNil: [ :e | | d | d := e dimensions. d isEmpty ifTrue: [ nil ] ifFalse: [ d first ] ]
]
