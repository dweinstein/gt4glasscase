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
		'nodesCache',
		'towers'
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

{ #category : 'honesty' }
GcSignalFlow >> archetypeCount [
	"How many distinct layer archetypes the main tower has. 1 == homogeneous (the diagram is exact); more == the diagram shows one representative block per archetype."
	self isInferred ifTrue: [ ^ 1 ].
	^ self mainTower ifNil: [ 0 ] ifNotNil: [ :t | t archetypeCount ]
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

{ #category : 'structure' }
GcSignalFlow >> auxHeadModuleSummary: aGroup [
	^ 'modules: ' , (', ' join: ((aGroup asArray collect: [ :t | self moduleLeafOf: t ]) asSet asSortedCollection))
]

{ #category : 'structure' }
GcSignalFlow >> auxiliaryHeadGroups [
	"Auxiliary prediction heads (e.g. an MTP head under the 'mtp' prefix): no-layer tensors that live in a distinct sub-namespace (a dotted prefix, i.e. >= 3 path parts) and are NOT the token embedding, final norm, lm_head, nor part of any layered tower. Grouped by top-level prefix; each value is a GcTensorGroup. Top-level trunk scalars (wte / wpe / ln_f) are 2-part and never counted."
	| claimed groups result |
	claimed := IdentitySet new.
	self claimSignatureOf: self embeddingTensor into: claimed.
	self claimSignatureOf: self finalNormTensor into: claimed.
	self claimSignatureOf: self lmHeadTensor into: claimed.
	groups := Dictionary new.
	tensorGroup do: [ :t |
		(t layerIndex isNil
			and: [ (self partsOf: t) size >= 3
			and: [ (claimed includes: t) not
			and: [ (self belongsToTowerPrefix: t) not ] ] ])
			ifTrue: [ (groups at: (self partsOf: t) first ifAbsentPut: [ OrderedCollection new ]) add: t ] ].
	result := Dictionary new.
	groups keysAndValuesDo: [ :k :oc | result at: k put: (GcTensorGroup withAll: oc) ].
	^ result
]

{ #category : 'accessing' }
GcSignalFlow >> auxiliaryTowers [
	"Non-main layered towers (e.g. a vision tower) -- rendered as their own labelled strands."
	^ self towers reject: [ :t | t isMain ]
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
	aKind = #tower ifTrue: [ ^ Color purple alpha: 0.16 ].
	aKind = #auxHead ifTrue: [ ^ Color magenta alpha: 0.12 ].
	^ Color white
]

{ #category : 'structure' }
GcSignalFlow >> belongsToTowerPrefix: aTensor [
	"True when a no-layer tensor sits under one of the layered towers' prefixes (e.g. a vision patch_embed / merger) -- such tensors belong to that tower's strand, not to an auxiliary head."
	^ self towers anySatisfy: [ :tw |
		tw prefix notEmpty and: [ aTensor name beginsWith: tw prefix , '.' ] ]
]

{ #category : 'building' }
GcSignalFlow >> buildArchetypeBlockFor: arch into: nodes isMain: aBoolean [
	"Build one representative block for an archetype (norm -> attention -> add -> norm -> MLP -> add) with the two bypass edges. Returns { entryNodes. exitNode }."
	| norms preRep postRep preNorm postNorm attn mlp attnInputs attnOutputs mlpInputs mlpOutputs attnAdd mlpAdd mlpEntry entryNodes |
	norms := self uniqueLeafRepsFrom: (arch normTensors asSortedCollection: [ :a :b | a name < b name ]).
	preRep := norms isEmpty ifTrue: [ nil ] ifFalse: [ norms first ].
	postRep := norms size >= 2 ifTrue: [ norms second ] ifFalse: [ nil ].
	preNorm := preRep ifNotNil: [ self nodeLabeled: (self moduleLeafOf: preRep) kind: #norm payload: (arch cohortForTensor: preRep) annotation: 'pre-attention norm' ].
	preNorm ifNotNil: [ preNorm badge: arch badgeString. nodes add: preNorm ].
	attn := self buildAttentionNodesFor: arch into: nodes.
	attnInputs := attn first. attnOutputs := attn second.
	attnAdd := self nodeLabeled: '(+) residual' kind: #add payload: nil annotation: 'attention add'.
	nodes add: attnAdd.
	attnInputs do: [ :n | attnOutputs isEmpty ifTrue: [ n addForward: attnAdd ] ifFalse: [ attnOutputs do: [ :o | n addForward: o ] ] ].
	attnOutputs do: [ :o | o addForward: attnAdd ].
	preNorm ifNotNil: [
		attnInputs notEmpty
			ifTrue: [ attnInputs do: [ :n | preNorm addForward: n ] ]
			ifFalse: [ attnOutputs notEmpty ifTrue: [ attnOutputs do: [ :o | preNorm addForward: o ] ] ifFalse: [ preNorm addForward: attnAdd ] ].
		preNorm addResidual: attnAdd ].
	postRep ifNotNil: [
		postNorm := self nodeLabeled: (self moduleLeafOf: postRep) kind: #norm payload: (arch cohortForTensor: postRep) annotation: 'pre-MLP norm'.
		nodes add: postNorm. attnAdd addForward: postNorm ].
	mlpEntry := postNorm ifNil: [ attnAdd ].
	mlp := self buildMlpNodesFor: arch into: nodes.
	mlpInputs := mlp first. mlpOutputs := mlp second.
	mlpAdd := self nodeLabeled: '(+) residual' kind: #add payload: nil annotation: 'MLP add'.
	nodes add: mlpAdd.
	mlpInputs do: [ :n | mlpEntry addForward: n. mlpOutputs isEmpty ifTrue: [ n addForward: mlpAdd ] ifFalse: [ mlpOutputs do: [ :o | n addForward: o ] ] ].
	mlpOutputs do: [ :o | o addForward: mlpAdd ].
	mlpInputs isEmpty ifTrue: [ mlpEntry addForward: mlpAdd ].
	attnAdd addResidual: mlpAdd.
	entryNodes := preNorm notNil
		ifTrue: [ OrderedCollection with: preNorm ]
		ifFalse: [ attnInputs notEmpty ifTrue: [ attnInputs ] ifFalse: [ attnOutputs notEmpty ifTrue: [ attnOutputs ] ifFalse: [ OrderedCollection with: attnAdd ] ] ].
	^ { entryNodes. mlpAdd }
]

{ #category : 'building' }
GcSignalFlow >> buildAttentionNodesFor: arch into: nodes [
	"Attention sublayer nodes for one archetype: real projection nodes, classified per family. Returns { inputNodes. outputNodes }."
	| reps outputs inputs inputNodes outputNodes labelTarget |
	reps := self uniqueLeafRepsFrom: arch attentionTensors.
	outputs := reps select: [ :t | self isAttentionOutputLeaf: (self moduleLeafOf: t) ].
	inputs := reps reject: [ :t | outputs includes: t ].
	inputNodes := inputs collect: [ :t | self nodeLabeled: (self moduleLeafOf: t) kind: #attention payload: (arch cohortForTensor: t) annotation: nil ].
	outputNodes := outputs collect: [ :t | self nodeLabeled: (self moduleLeafOf: t) kind: #attention payload: (arch cohortForTensor: t) annotation: nil ].
	labelTarget := inputNodes isEmpty ifTrue: [ outputNodes ] ifFalse: [ inputNodes ].
	labelTarget ifNotEmpty: [ :c | c first annotation: arch attentionKindLabel ].
	nodes addAll: inputNodes; addAll: outputNodes.
	^ { inputNodes. outputNodes }
]

{ #category : 'building' }
GcSignalFlow >> buildAuxiliaryTowerStrand: aTower into: nodes [
	"Render a non-main tower (e.g. vision, or a small MTP head-tower) as its own labelled strand: title -> optional patch/pos embed -> archetype block(s) -> a node for the tower's remaining no-layer pieces (merger / MTP fc+norm glue). Never merged into the main chain."
	| title prev embedCohort others posKeys |
	posKeys := #('patch' 'pos_embed' 'position_embed').
	title := self nodeLabeled: aTower name , ' tower' kind: #tower payload: aTower annotation: aTower summaryString.
	nodes add: title.
	prev := title.
	embedCohort := self towerNoLayerCohortOf: aTower matchingAny: posKeys.
	embedCohort isEmpty ifFalse: [ | pn |
		pn := self nodeLabeled: 'patch/pos embed' kind: #embedding payload: embedCohort annotation: nil.
		nodes add: pn. prev addForward: pn. prev := pn ].
	aTower archetypes do: [ :arch | | block |
		block := self buildArchetypeBlockFor: arch into: nodes isMain: false.
		(block first) do: [ :n | prev addForward: n ].
		prev := block second ].
	others := self towerNoLayerOthersOf: aTower excludingAny: posKeys.
	others isEmpty ifFalse: [ | on |
		on := self nodeLabeled: aTower name , ' head' kind: #auxHead payload: others annotation: (self auxHeadModuleSummary: others).
		nodes add: on. prev addForward: on ].
	^ self
]

{ #category : 'building' }
GcSignalFlow >> buildFromTensors [
	"Segment the checkpoint into towers + non-layer pieces, then assemble the graph: token ids -> embedding -> the main tower's archetype blocks (one per distinct layer kind) -> final norm -> lm_head -> logits, plus any auxiliary heads (MTP) and auxiliary towers (vision) as their own strands. No cross-archetype/cross-tower merging."
	| nodes badge tokens embed prev main finalNorm head logits embedT finalT headT |
	self ensureSegmented.
	nodes := OrderedCollection new.
	main := self mainTower.
	embedT := self embeddingTensor.
	finalT := self finalNormTensor.
	headT := self lmHeadTensor.
	badge := self nodeLabeled: self honestyTitle kind: #legend payload: nil annotation: self towerSummary.
	tokens := self nodeLabeled: 'token ids' kind: #tokens payload: nil annotation: nil.
	nodes add: badge; add: tokens.
	badge addForward: tokens.
	prev := tokens.
	embedT ifNotNil: [
		embed := self nodeLabeled: (self moduleLeafOf: embedT) kind: #embedding payload: (self cohortFor: embedT) annotation: (self embeddingAnnotation: embedT).
		nodes add: embed. prev addForward: embed. prev := embed ].
	main ifNotNil: [
		main archetypes do: [ :arch | | block |
			block := self buildArchetypeBlockFor: arch into: nodes isMain: true.
			(block first) do: [ :n | prev addForward: n ].
			prev := block second ] ].
	finalT ifNotNil: [
		finalNorm := self nodeLabeled: 'final norm' kind: #finalNorm payload: (self cohortFor: finalT) annotation: (self moduleLeafOf: finalT).
		nodes add: finalNorm. prev addForward: finalNorm. prev := finalNorm ].
	head := self nodeLabeled: (headT isNil ifTrue: [ 'lm_head (tied)' ] ifFalse: [ self moduleLeafOf: headT ])
		kind: #head
		payload: (headT isNil ifTrue: [ embedT ifNotNil: [ self cohortFor: embedT ] ] ifFalse: [ self cohortFor: headT ])
		annotation: (self headAnnotationFor: headT).
	nodes add: head. prev addForward: head.
	logits := self nodeLabeled: 'logits' kind: #output payload: nil annotation: nil.
	nodes add: logits. head addForward: logits.
	self auxiliaryHeadGroups keysAndValuesDo: [ :pfx :grp | | headNode |
		headNode := self nodeLabeled: pfx , ' (aux head)' kind: #auxHead payload: grp annotation: (self auxHeadModuleSummary: grp).
		nodes add: headNode.
		(finalNorm ifNil: [ prev ]) addForward: headNode ].
	self auxiliaryTowers do: [ :tower | self buildAuxiliaryTowerStrand: tower into: nodes ].
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

{ #category : 'building' }
GcSignalFlow >> buildMlpNodesFor: arch into: nodes [
	"MLP sublayer nodes for one archetype. Returns { inputNodes. outputNodes }."
	| reps outputs inputs inputNodes outputNodes |
	arch isMoE ifTrue: [ ^ self buildMoeNodesFor: arch into: nodes ].
	reps := self uniqueLeafRepsFrom: arch mlpTensors.
	outputs := reps select: [ :t | self isMlpOutputLeaf: (self moduleLeafOf: t) ].
	inputs := reps reject: [ :t | outputs includes: t ].
	inputNodes := inputs withIndexCollect: [ :t :i | self nodeLabeled: (self moduleLeafOf: t) kind: #mlp payload: (arch cohortForTensor: t) annotation: (i = 1 ifTrue: [ arch mlpKindLabel ] ifFalse: [ nil ]) ].
	outputNodes := outputs collect: [ :t | self nodeLabeled: (self moduleLeafOf: t) kind: #mlp payload: (arch cohortForTensor: t) annotation: (self mlpAnnotation: t) ].
	(inputNodes isEmpty and: [ outputNodes notEmpty ]) ifTrue: [ outputNodes first annotation: arch mlpKindLabel ].
	nodes addAll: inputNodes; addAll: outputNodes.
	^ { inputNodes. outputNodes }
]

{ #category : 'building' }
GcSignalFlow >> buildMoeNodesFor: arch into: nodes [
	"Compact MoE MLP nodes: router (gate), experts x N, optional shared expert -- all parallel into the residual add. Returns { inputNodes. {} }."
	| out |
	out := OrderedCollection new.
	(arch mlpTensors detect: [ :t | (self moduleLeafOf: t) = 'gate' ] ifNone: [ nil ]) ifNotNil: [ :g |
		out add: (self nodeLabeled: 'router (gate)' kind: #mlp payload: (arch cohortForTensor: g) annotation: 'top-k routing') ].
	out add: (self nodeLabeled: 'experts' kind: #mlp payload: (arch cohortMatchingName: 'experts') annotation: arch mlpKindLabel).
	arch hasSharedExpert ifTrue: [
		out add: (self nodeLabeled: 'shared expert' kind: #mlp payload: (arch cohortMatchingName: 'shared_expert') annotation: 'always-on path') ].
	nodes addAll: out.
	^ { out. OrderedCollection new }
]

{ #category : 'derivation' }
GcSignalFlow >> buildNodes [
	^ self hasTensors
		ifTrue: [ self buildFromTensors ]
		ifFalse: [ self buildInferredNodes ]
]

{ #category : 'structure' }
GcSignalFlow >> claimSignatureOf: aTensor into: aSet [
	"Claim every tensor sharing aTensor's slot signature (e.g. a norm's .weight AND .bias) so trunk pieces are never mistaken for an auxiliary head."
	| sig |
	aTensor ifNil: [ ^ self ].
	sig := self signatureOf: aTensor.
	tensorGroup do: [ :t | (self signatureOf: t) = sig ifTrue: [ aSet add: t ] ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> cohortFor: aTensor [
	"The GcTensorGroup of every tensor in this checkpoint that occupies the same slot as aTensor across all layers."
	| sig |
	sig := self signatureOf: aTensor.
	^ tensorGroup select: [ :t | (self signatureOf: t) = sig ]
]

{ #category : 'segmentation' }
GcSignalFlow >> computeMainArchetypeFlags [
	"Set the top-level fused/gated flags from the main tower's representative archetype (backwards-compatible summary for the homogeneous case)."
	| arch |
	attentionFused := false.
	mlpGated := false.
	arch := self mainTower ifNil: [ ^ self ].
	arch := arch firstArchetype ifNil: [ ^ self ].
	attentionFused := arch attentionKind = #fused.
	mlpGated := (arch mlpKind = #gated) or: [ arch mlpKind = #moe ]
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

{ #category : 'structure' }
GcSignalFlow >> embeddingTensor [
	"The language token embedding tensor (vocab x hidden), or nil."
	^ tensorGroup
		detect: [ :t | t layerIndex isNil and: [ self isTokenEmbeddingName: t name ] ]
		ifNone: [ nil ]
]

{ #category : 'segmentation' }
GcSignalFlow >> ensureSegmented [
	"Partition the tensor names into towers (once). Reads only loaded state (I5)."
	towers ifNotNil: [ ^ self ].
	self hasTensors ifFalse: [ towers := #(). ^ self ].
	self segmentTowers.
	self computeMainArchetypeFlags
]

{ #category : 'structure' }
GcSignalFlow >> finalNormTensor [
	"The main tower's final norm, preferring one sharing the main tower prefix."
	| candidates mainPrefix hit |
	candidates := tensorGroup select: [ :t | t layerIndex isNil and: [ self isFinalNormName: t name ] ].
	candidates isEmpty ifTrue: [ ^ nil ].
	mainPrefix := self mainTower ifNotNil: [ :m | m prefix ].
	(mainPrefix notNil and: [ mainPrefix notEmpty ]) ifTrue: [
		hit := candidates detect: [ :t | t name includesSubstring: mainPrefix , '.norm' ] ifNone: [ nil ].
		hit ifNotNil: [ ^ hit ] ].
	^ candidates anyOne
]

{ #category : 'gt views' }
GcSignalFlow >> gtSignalFlowFor: aView [
	"What is the shape of the computation this checkpoint performs? A control-system block diagram: token ids -> embedding -> the main tower's archetype blocks (one representative block per DISTINCT layer kind, badged with its layer count/range) -> final norm -> lm_head -> logits, with the residual/skip bypass edges (dashed orange) around each block's attention and MLP sublayers. Auxiliary heads (e.g. MTP) and auxiliary towers (e.g. a vision tower) are drawn as their own separate strands -- never merged into the main block. The legend node carries the honesty badge (archetype/tower counts; faithful vs representative)."
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

{ #category : 'structure' }
GcSignalFlow >> headAnnotationFor: aTensor [
	"Head dimensions read from the REAL lm_head tensor shape ([vocab, hidden]); falls back to config-derived dims when tied/absent."
	| d |
	aTensor isNil ifTrue: [ ^ 'tied to embedding · ' , self headAnnotation ].
	d := aTensor dimensions.
	^ d size >= 2
		ifTrue: [ d last printString , ' x ' , d first printString , ' (hidden x vocab, from lm_head)' ]
		ifFalse: [ self headAnnotation ]
]

{ #category : 'derivation - facts' }
GcSignalFlow >> hiddenSizeValue [
	architecture ifNotNil: [ :a | a hiddenSize ifNotNil: [ :h | ^ h ] ].
	self hasTensors ifFalse: [ ^ nil ].
	^ self embeddingTensor
		ifNil: [ nil ]
		ifNotNil: [ :e | | d | d := e dimensions. d isEmpty ifTrue: [ nil ] ifFalse: [ d last ] ]
]

{ #category : 'honesty' }
GcSignalFlow >> honestyTitle [
	"A short structural style name for the badge, augmented with +MoE / +SSM / +VLM when those are present."
	| base extras main |
	self isInferred ifTrue: [ ^ 'inferred (config)' ].
	base := self modelStyleName.
	extras := OrderedCollection new.
	main := self mainTower.
	(main notNil and: [ main archetypes anySatisfy: [ :a | a isMoE ] ]) ifTrue: [ extras add: 'MoE' ].
	(main notNil and: [ main archetypes anySatisfy: [ :a | a hasLinearAttention ] ]) ifTrue: [ extras add: 'SSM' ].
	(self auxiliaryTowers anySatisfy: [ :t | t name = 'vision' ]) ifTrue: [ extras add: 'VLM' ].
	^ extras isEmpty ifTrue: [ base ] ifFalse: [ base , ' +' , ('+' join: extras) ]
]

{ #category : 'derivation - parsing' }
GcSignalFlow >> isAttentionOutputLeaf: aLeaf [
	^ #('o_proj' 'c_proj' 'out_proj' 'dense' 'wo' 'proj') includes: aLeaf
]

{ #category : 'structure' }
GcSignalFlow >> isFinalNormName: aName [
	"A model-level final norm (model.norm / ln_f / final_layer_norm), excluding vision/MTP/merger norms and any embedding."
	| lower |
	lower := aName asLowercase.
	((lower includesSubstring: 'mtp') or: [ (lower includesSubstring: 'visual')
		or: [ (lower includesSubstring: 'vision') or: [ (lower includesSubstring: 'patch')
		or: [ (lower includesSubstring: 'merger') or: [ lower includesSubstring: 'embed' ] ] ] ] ])
		ifTrue: [ ^ false ].
	^ (lower includesSubstring: 'norm') or: [ lower includesSubstring: 'ln_f' ]
]

{ #category : 'honesty' }
GcSignalFlow >> isHomogeneous [
	"True when the diagram is faithful rather than representative: a single layered tower, one archetype, no auxiliary heads."
	self isInferred ifTrue: [ ^ true ].
	self hasTensors ifFalse: [ ^ true ].
	^ (self towers size = 1)
		and: [ self archetypeCount = 1
		and: [ self auxiliaryHeadGroups isEmpty ] ]
]

{ #category : 'testing' }
GcSignalFlow >> isInferred [
	^ inferred == true
]

{ #category : 'segmentation' }
GcSignalFlow >> isLayerWord: aString [
	^ #('layers' 'h' 'blocks' 'block') includes: aString
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

{ #category : 'structure' }
GcSignalFlow >> isTokenEmbeddingName: aName [
	"True only for the LANGUAGE token embedding -- never a vision patch/pos embedding nor an MTP head's norm (which merely contains the substring 'embed')."
	| lower |
	lower := aName asLowercase.
	(lower includesSubstring: 'norm') ifTrue: [ ^ false ].
	((lower includesSubstring: 'patch') or: [ (lower includesSubstring: 'pos_embed')
		or: [ (lower includesSubstring: 'visual') or: [ (lower includesSubstring: 'vision')
		or: [ lower includesSubstring: 'mtp' ] ] ] ]) ifTrue: [ ^ false ].
	^ (lower includesSubstring: 'embed_tokens')
		or: [ (lower includesSubstring: 'wte')
		or: [ (lower includesSubstring: 'embed_in')
		or: [ (lower includesSubstring: 'word_embeddings')
		or: [ lower includesSubstring: 'tok_embeddings' ] ] ] ]
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

{ #category : 'building' }
GcSignalFlow >> layerZeroTensors [
	"The representative block tensors: the main tower's first archetype's representative layer. For a homogeneous single-tower model this is layer 0 (unchanged); for a multi-tower model it EXCLUDES other towers (fixing the cross-tower union bug)."
	| main |
	self hasTensors ifFalse: [ ^ GcTensorGroup withAll: #() ].
	main := self mainTower.
	main ifNil: [ ^ GcTensorGroup withAll: #() ].
	^ main firstArchetype
		ifNil: [ GcTensorGroup withAll: #() ]
		ifNotNil: [ :a | a representativeTensors ]
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

{ #category : 'accessing' }
GcSignalFlow >> mainTower [
	"The tower carrying the token stream to the head (most layers, preferring a language/main prefix)."
	^ self towers detect: [ :t | t isMain ] ifNone: [ self towers isEmpty ifTrue: [ nil ] ifFalse: [ self towers first ] ]
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

{ #category : 'segmentation' }
GcSignalFlow >> segmentTowers [
	"Group every per-layer tensor by its tower key; the main tower is the largest one whose default role is #main (else simply the largest)."
	| byKey towerList main |
	byKey := Dictionary new.
	tensorGroup do: [ :t | | k |
		k := self towerKeyOf: t.
		k ifNotNil: [ (byKey at: k ifAbsentPut: [ OrderedCollection new ]) add: t ] ].
	towerList := byKey associations collect: [ :assoc |
		GcSignalTower flow: self key: assoc key tensors: (GcTensorGroup withAll: assoc value) ].
	towerList := (towerList asSortedCollection: [ :a :b | a layerCount > b layerCount ]) asArray.
	main := towerList
		detect: [ :t | t role = #main ]
		ifNone: [ towerList isEmpty ifTrue: [ nil ] ifFalse: [ towerList first ] ].
	towerList do: [ :t | t role: (t == main ifTrue: [ #main ] ifFalse: [ #auxiliary ]) ].
	towers := towerList
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

{ #category : 'segmentation' }
GcSignalFlow >> towerKeyOf: aTensor [
	"The tower key of a per-layer tensor: the dotted path up to AND INCLUDING the layer word (layers / h / blocks / block), or nil if this is not a per-layer tensor of a recognised layer stack. Tower-prefix agnostic: works for model.layers, model.language_model.layers, transformer.h, model.visual.blocks, gpt_neox.layers, ..."
	| parts pos word |
	parts := self partsOf: aTensor.
	pos := self layerPositionIn: parts.
	pos < 2 ifTrue: [ ^ nil ].
	word := parts at: pos - 1.
	(self isLayerWord: word) ifFalse: [ ^ nil ].
	^ '.' join: (parts first: pos - 1)
]

{ #category : 'structure' }
GcSignalFlow >> towerNoLayerCohortOf: aTower matchingAny: substrings [
	"No-layer tensors under aTower's prefix whose name contains any of substrings (e.g. a vision patch/pos embed) -- a GcTensorGroup for drill-in."
	^ tensorGroup select: [ :t |
		t layerIndex isNil
			and: [ (aTower prefix notEmpty and: [ t name beginsWith: aTower prefix , '.' ])
			and: [ substrings anySatisfy: [ :s | t name asLowercase includesSubstring: s ] ] ] ]
]

{ #category : 'structure' }
GcSignalFlow >> towerNoLayerOthersOf: aTower excludingAny: substrings [
	"No-layer tensors under aTower's prefix that are NOT matched by substrings (e.g. a vision merger, or an MTP head's fc/norm/pre_fc_norm glue) -- a GcTensorGroup for drill-in."
	^ tensorGroup select: [ :t |
		t layerIndex isNil
			and: [ (aTower prefix notEmpty and: [ t name beginsWith: aTower prefix , '.' ])
			and: [ (substrings anySatisfy: [ :s | t name asLowercase includesSubstring: s ]) not ] ] ]
]

{ #category : 'honesty' }
GcSignalFlow >> towerSummary [
	"A one-line honesty caption: main tower archetype/layer counts, any auxiliary towers and heads, and whether the diagram is faithful or representative."
	| parts main |
	self isInferred ifTrue: [ ^ 'inferred from config (canonical llama-style)' ].
	parts := OrderedCollection new.
	main := self mainTower.
	main ifNotNil: [ parts add: main name , ' tower: ' , main summaryString ].
	self auxiliaryTowers do: [ :t | parts add: '+' , t name , '(' , t layerCount printString , ')' ].
	self auxiliaryHeadGroups keys asSortedCollection do: [ :k | parts add: '+' , k ].
	parts add: (self isHomogeneous ifTrue: [ 'faithful' ] ifFalse: [ 'representative blocks' ]).
	^ ' · ' join: parts
]

{ #category : 'accessing' }
GcSignalFlow >> towers [
	"The layered towers of this checkpoint (main + any auxiliary vision/audio towers)."
	self ensureSegmented.
	^ towers
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
