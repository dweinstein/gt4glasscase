"
gtExample methods proving the GPT-2 forward pass and greedy generation against the real openai-community/gpt2 weights in the local glassbox cache. decodeFixturePromptExample is a plain automated example (reads only vocab.json). The end-to-end examples are <noTest> because they load ~500MB of weights and run compute-heavy forwards: singleShotCapitalOfFranceExample documents the model's genuine single-shot behavior, while inContextGreedyParisExample, capitalAnalogyBerlinExample and continuationDemoExample prove genuine ' Paris' / ' Berlin' greedy outcomes from in-context prompts.
"
Class {
	#name : 'GcGpt2InferenceExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'asserting' }
GcGpt2InferenceExamples >> assert: actual equals: expected [
	actual = expected ifFalse: [ self error: 'expected ', expected printString, ' but got ', actual printString ]
]

{ #category : 'asserting' }
GcGpt2InferenceExamples >> assertTrue: aBoolean [
	aBoolean ifFalse: [ self error: 'assertion failed' ]
]

{ #category : 'examples - kv cache' }
GcGpt2InferenceExamples >> cachedAttentionMatchesFullAttentionExample [
	<gtExample>
	"Hermetic correctness of the KV-cache attention math -- no weights. On a tiny 2-head / headDim-2 (hiddenSize 4) case with known q/k/v, the single-query cached attention (cachedAttentionQuery:scale:keys:values:) must equal the LAST position of the full causal attention (attentionFrom:seqLen:scale:) to floating-point exactness. This isolates the cache attention from the 500MB weights and is the automated guardrail for the mathematical-identity claim."
	| model d seqLen scale qkv full cache cached maxDiff |
	d := 4.
	model := GcGpt2Model new.
	model instVarNamed: 'hiddenSize' put: d.
	model instVarNamed: 'numHeads' put: 2.
	model instVarNamed: 'headDim' put: 2.
	seqLen := 3.
	scale := 0.5.
	qkv := (1 to: seqLen) collect: [ :i |
		| a |
		a := Float64Array new: 3 * d.
		1 to: 3 * d do: [ :t | a at: t put: ((i * 0.1) + (t * 0.03)) sin ].
		a ].
	full := model attentionFrom: qkv seqLen: seqLen scale: scale.
	cache := GcKvCache new numLayers: 1.
	1 to: seqLen do: [ :i |
		| kv key val |
		kv := qkv at: i.
		key := Float64Array new: d.
		val := Float64Array new: d.
		1 to: d do: [ :t | key at: t put: (kv at: d + t). val at: t put: (kv at: 2 * d + t) ].
		cache appendKey: key value: val forLayer: 0 ].
	cached := model cachedAttentionQuery: (qkv at: seqLen) scale: scale keys: (cache keysForLayer: 0) values: (cache valuesForLayer: 0).
	maxDiff := self maxAbsDiffBetween: (full at: seqLen) and: cached.
	self assertTrue: maxDiff <= 1e-9.
	^ maxDiff
]

{ #category : 'examples - kv cache' }
GcGpt2InferenceExamples >> cachedEqualsUncachedTokensExample [
	<gtExample>
	<noTest>
	"Token-identity + speedup on the real weights. Generate 4 tokens from the in-context prompt via BOTH the KV-cached path (generateCachedFromTokenIds:maxTokens:) and the uncached path (generateFromTokenIds:maxTokens:); the two generatedIds sequences must be EQUAL (a cache bug shows up as divergent ids). Reports both wall-times and the speedup. noTest: loads ~500MB and runs both paths."
	| model ids cachedGen uncachedGen cachedMs uncachedMs cachedIds uncachedIds result |
	model := GcGpt2Model default.
	ids := self franceInContextPromptIds.
	cachedMs := [ cachedGen := model generateCachedFromTokenIds: ids maxTokens: 4 ] millisecondsToRun.
	uncachedMs := [ uncachedGen := model generateFromTokenIds: ids maxTokens: 4 ] millisecondsToRun.
	cachedIds := cachedGen generatedIds asArray.
	uncachedIds := uncachedGen generatedIds asArray.
	self assert: cachedIds equals: uncachedIds.
	result := Dictionary new.
	result
		at: #cachedIds put: cachedIds;
		at: #uncachedIds put: uncachedIds;
		at: #cachedMs put: cachedMs;
		at: #uncachedMs put: uncachedMs;
		at: #speedup put: (uncachedMs / (cachedMs max: 1)) asFloat;
		at: #generation put: cachedGen.
	^ result
]

{ #category : 'examples - kv cache' }
GcGpt2InferenceExamples >> cachedPrefillMatchesUncachedExample [
	<gtExample>
	<noTest>
	"Mathematical identity of the KV-cache path against the uncached forward, on the real gpt2-124M weights. (1) prefillTokenIds:cache: over the in-context prompt must give last-position logits equal to forwardTokenIds: (max-abs diff <= 1e-6). (2) then decodeToken: one token must equal a fresh uncached forwardTokenIds: over prompt+thatToken (<= 1e-6). Proves prefill and decode are numerically identical to full recomputation. noTest: loads ~500MB and runs ~3 forwards."
	| model ids cache prefillLogits fullLogits prefillDiff tok decodeLogits fullLogits2 decodeDiff result |
	model := GcGpt2Model default.
	ids := self franceInContextPromptIds.
	cache := GcKvCache new numLayers: model numLayers.
	prefillLogits := model prefillTokenIds: ids cache: cache.
	fullLogits := model forwardTokenIds: ids.
	prefillDiff := self maxAbsDiffBetween: prefillLogits and: fullLogits.
	self assertTrue: prefillDiff <= 1e-6.
	tok := GcTensorMath argmax: prefillLogits.
	decodeLogits := model decodeToken: tok cache: cache.
	fullLogits2 := model forwardTokenIds: (ids asArray , (Array with: tok)).
	decodeDiff := self maxAbsDiffBetween: decodeLogits and: fullLogits2.
	self assertTrue: decodeDiff <= 1e-6.
	self assert: cache seqLength equals: ids size + 1.
	result := Dictionary new.
	result
		at: #prefillMaxAbsDiff put: prefillDiff;
		at: #decodeMaxAbsDiff put: decodeDiff;
		at: #decodedToken put: tok;
		at: #cacheSeqLength put: cache seqLength;
		at: #cacheBytes put: cache memoryBytes.
	^ result
]

{ #category : 'examples' }
GcGpt2InferenceExamples >> capitalAnalogyBerlinExample [
	<gtExample>
	<noTest>
	"A stronger faithfulness proof of the forward pass: 'The capital of France is Paris. The capital of Germany is' greedily predicts ' Berlin' (id 11307) as the #1 next token (its top-5 are all German cities). A one-shot analogy a buggy forward could not produce -- strong evidence the GPT-2 forward pass is correct."
	| model ids logits greedyId decoded result |
	model := GcGpt2Model default.
	ids := self germanyAnalogyPromptIds.
	logits := model forwardTokenIds: ids.
	greedyId := GcTensorMath argmax: logits.
	decoded := GcGpt2Decoder default decodeId: greedyId.
	result := Dictionary new.
	result at: #greedyId put: greedyId; at: #decoded put: decoded; at: #logitsSize put: logits size.
	self assert: logits size equals: 50257.
	self assert: greedyId equals: 11307.
	self assert: decoded equals: ' Berlin'.
	^ result
]

{ #category : 'prompts' }
GcGpt2InferenceExamples >> capitalOfFrancePromptIds [
	"Token ids for 'The capital of France is' (the bare zero-shot prompt)."
	^ #(464 3139 286 4881 318)
]

{ #category : 'examples' }
GcGpt2InferenceExamples >> continuationDemoExample [
	<gtExample>
	<noTest>
	"The outcome jump: greedy MULTI-token generation. From 'The capital of France is Paris. The capital of France is', greedily generate 8 tokens; the continuation begins with ' Paris'. Uses the in-context prompt so the demonstrated ' Paris' continuation is a genuine model outcome (GPT-2-124M is too weak to produce it zero-shot; see singleShotCapitalOfFranceExample). Returns the GcGeneration (open its Tokens / Text views)."
	| model gen continuation |
	model := GcGpt2Model default.
	gen := model generateFromTokenIds: self franceInContextPromptIds maxTokens: 8.
	continuation := gen generatedText.
	self assert: gen generatedIds size equals: 8.
	self assertTrue: (continuation beginsWith: ' Paris').
	^ gen
]

{ #category : 'examples' }
GcGpt2InferenceExamples >> decodeFixturePromptExample [
	<gtExample>
	"Decode the fixed GPT-2 token ids for 'The capital of France is' and assert the exact string. Reads only vocab.json -- deterministic, no weights, so this joins the automated suite."
	| decoded |
	decoded := GcGpt2Decoder default decodeIds: #(464 3139 286 4881 318).
	self assert: decoded equals: 'The capital of France is'.
	^ decoded
]

{ #category : 'prompts' }
GcGpt2InferenceExamples >> franceInContextPromptIds [
	"Token ids for 'The capital of France is Paris. The capital of France is' -- the fact stated once, then re-primed, so greedy induction yields ' Paris'."
	^ #(464 3139 286 4881 318 6342 13 383 3139 286 4881 318)
]

{ #category : 'prompts' }
GcGpt2InferenceExamples >> germanyAnalogyPromptIds [
	"Token ids for 'The capital of France is Paris. The capital of Germany is' -- a one-shot analogy whose greedy answer is ' Berlin'."
	^ #(464 3139 286 4881 318 6342 13 383 3139 286 4486 318)
]

{ #category : 'examples' }
GcGpt2InferenceExamples >> inContextGreedyParisExample [
	<gtExample>
	<noTest>
	"The genuine ' Paris' greedy outcome. Prompt: 'The capital of France is Paris. The capital of France is'. With the fact given in-context, GPT-2-124M greedily and unambiguously predicts ' Paris' (id 6342) as the #1 next token. This proves the forward pass + greedy argmax end-to-end on a real ' Paris' outcome (a faithful demonstration, since the bare zero-shot prompt exceeds GPT-2-small's factual recall -- see singleShotCapitalOfFranceExample)."
	| model ids logits ms greedyId decoded result |
	model := GcGpt2Model default.
	ids := self franceInContextPromptIds.
	ms := [ logits := model forwardTokenIds: ids ] millisecondsToRun.
	greedyId := GcTensorMath argmax: logits.
	decoded := GcGpt2Decoder default decodeId: greedyId.
	result := Dictionary new.
	result at: #forwardMs put: ms; at: #greedyId put: greedyId; at: #decoded put: decoded; at: #logitsSize put: logits size.
	self assert: logits size equals: 50257.
	self assert: greedyId equals: 6342.
	self assert: decoded equals: ' Paris'.
	^ result
]

{ #category : 'examples - end to end' }
GcGpt2InferenceExamples >> inContextGreedyParisF32WeightsExample [
	<gtExample>
	<noTest>
	"END-TO-END proof that the #f32 weight-STORAGE optimization is behavior-preserving AND halves memory. On FRESH models (the shared GcGpt2Model default is left pristine #f64), weights stored as Float32Array still greedily and unambiguously predict ' Paris' (id 6342) for the in-context France prompt -- argmax is stable under f32 storage. Reports the honest resident-memory delta (the f32 weight cache is exactly half the f64 cache) and the forward-time delta (both compute in doubles; #f32 changes only STORAGE, so the times are comparable). Slow: two cold ~124M-param weight decodes -- hence <noTest>."
	| ids f64model f64ms f64logits f64id f64bytes f32model f32ms f32logits f32id f32bytes result |
	ids := self franceInContextPromptIds.
	f64model := GcGpt2Model openDefault.
	f64ms := [ f64logits := f64model forwardTokenIds: ids ] millisecondsToRun.
	f64id := GcTensorMath argmax: f64logits.
	f64bytes := self weightFootprintBytesOf: f64model.
	f64model unloadWeights.
	f32model := GcGpt2Model openDefault.
	f32model weightDtype: #f32.
	f32ms := [ f32logits := f32model forwardTokenIds: ids ] millisecondsToRun.
	f32id := GcTensorMath argmax: f32logits.
	f32bytes := self weightFootprintBytesOf: f32model.
	f32model unloadWeights.
	self assert: f64id equals: 6342.
	self assert: f32id equals: 6342.
	self assert: (GcGpt2Decoder default decodeId: f32id) equals: ' Paris'.
	self assertTrue: (f32bytes * 2 - f64bytes) abs <= (f64bytes // 100).
	result := Dictionary new.
	result
		at: #f64GreedyId put: f64id;
		at: #f32GreedyId put: f32id;
		at: #f32Decoded put: (GcGpt2Decoder default decodeId: f32id);
		at: #f64Bytes put: f64bytes;
		at: #f32Bytes put: f32bytes;
		at: #f64MB put: (f64bytes / 1048576.0) rounded;
		at: #f32MB put: (f32bytes / 1048576.0) rounded;
		at: #memoryRatio put: (f32bytes / f64bytes) asFloat;
		at: #f64ForwardMs put: f64ms;
		at: #f32ForwardMs put: f32ms.
	^ result
]

{ #category : 'examples - kv cache' }
GcGpt2InferenceExamples >> kvCacheAccumulationExample [
	<gtExample>
	"Hermetic cache mechanics -- no weights. Append K/V for a couple of positions to two layers and check seqLength, per-layer sizes, memoryBytes (8 bytes/Float64 element) and reset. Proves the GcKvCache bookkeeping the decode path relies on."
	| cache k v |
	cache := GcKvCache new numLayers: 2.
	k := Float64Array new: 4. v := Float64Array new: 4.
	1 to: 4 do: [ :t | k at: t put: t asFloat. v at: t put: (t * 10) asFloat ].
	cache appendKey: k value: v forLayer: 0.
	cache appendKey: k copy value: v copy forLayer: 1.
	cache appendKey: k copy value: v copy forLayer: 0.
	self assert: cache seqLength equals: 2.
	self assert: (cache keysForLayer: 0) size equals: 2.
	self assert: (cache keysForLayer: 1) size equals: 1.
	self assert: cache memoryBytes equals: (4 + 2) * 4 * 8.
	cache reset.
	self assert: cache seqLength equals: 0.
	self assert: cache memoryBytes equals: 0.
	^ cache
]

{ #category : 'asserting' }
GcGpt2InferenceExamples >> maxAbsDiffBetween: a and: b [
	"Maximum absolute element-wise difference between two equal-length numeric vectors."
	| m |
	m := 0.0.
	1 to: a size do: [ :i | | diff | diff := ((a at: i) - (b at: i)) abs. diff > m ifTrue: [ m := diff ] ].
	^ m
]

{ #category : 'examples - architecture' }
GcGpt2InferenceExamples >> modelArchitectureUnifiedFacetsFromGpt2Model [
	"The running GPT-2 model answers the unified TGcModelArchitecture facets through the SAME trait as the model-source side, and its structural views (skyline / signal-flow / tree) REUSE the existing structural objects -- all from the local safetensors header + config, WITHOUT decoding weights or running a forward. Deterministic (header shape products), so it joins the automated suite alongside decodeFixturePromptExample."
	<gtExample>
	| model flow source |
	model := GcGpt2Model default.
	self assert: model numLayers equals: 12.
	self assert: model numHeads equals: 12.
	self assert: model numKvHeads equals: 12.
	self assert: model headDim equals: 64.
	self assert: model hiddenSize equals: 768.
	self assert: model vocabSize equals: 50257.
	self assert: model numParameters equals: 137022720.
	self assert: model modelDtype equals: #f32.
	self assertTrue: (model architecture isKindOf: GcArchitecture).
	self assert: model architecture vocabSize equals: 50257.
	self assert: model architectureFacets size equals: 9.
	self assert: model tensorGroup layerIndices size equals: 12.
	flow := GcSignalFlow fromTensorGroup: model tensorGroup architecture: model architecture.
	self assertTrue: flow attentionFused.
	self assert: flow modelStyleName equals: 'gpt2-style'.
	source := model modelSource.
	self assertTrue: (source isKindOf: GcInMemoryModelSource).
	self assertTrue: source isMetadataLoaded.
	self assert: source loadedArchitecture numLayers equals: 12.
	self assertTrue: ((model gtOverviewFor: GtPhlowView empty) isKindOf: GtPhlowEmptyView) not.
	self assertTrue: ((model gtModelFactsFor: GtPhlowView empty) isKindOf: GtPhlowEmptyView) not.
	self assertTrue: ((model gtSkylineFor: GtPhlowView empty) isKindOf: GtPhlowEmptyView) not.
	self assertTrue: ((model gtSignalFlowFor: GtPhlowView empty) isKindOf: GtPhlowEmptyView) not.
	self assertTrue: ((model gtTreeFor: GtPhlowView empty) isKindOf: GtPhlowEmptyView) not.
	^ model
]

{ #category : 'examples' }
GcGpt2InferenceExamples >> singleShotCapitalOfFranceExample [
	<gtExample>
	<noTest>
	"Forward the bare zero-shot prompt 'The capital of France is' through the real GPT-2-124M weights and document the model's genuine single-shot behavior: the greedy top token is ' the' -- GPT-2-small is too weak to place ' Paris' first zero-shot -- yet ' Paris' (id 6342) sits within the top-5, so the fact IS represented. Asserts logits size 50257 and that ' Paris' is in the top-5. (The genuine ' Paris' / ' Berlin' greedy outcomes are proven by inContextGreedyParisExample and capitalAnalogyBerlinExample.)"
	| model ids logits ms greedyId top5 result |
	model := GcGpt2Model default.
	ids := self capitalOfFrancePromptIds.
	ms := [ logits := model forwardTokenIds: ids ] millisecondsToRun.
	greedyId := GcTensorMath argmax: logits.
	top5 := self topKIdsFor: logits k: 5.
	result := Dictionary new.
	result
		at: #forwardMs put: ms;
		at: #greedyId put: greedyId;
		at: #greedyPiece put: (GcGpt2Decoder default decodeId: greedyId);
		at: #top5 put: (top5 collect: [ :id | id -> (GcGpt2Decoder default decodeId: id) ]);
		at: #parisRank put: (top5 indexOf: 6342);
		at: #logitsSize put: logits size.
	self assert: logits size equals: 50257.
	self assertTrue: (top5 includes: 6342).
	^ result
]

{ #category : 'asserting' }
GcGpt2InferenceExamples >> topKIdsFor: logits k: k [
	"The token ids of the k largest logits, highest first."
	| pairs |
	pairs := (1 to: logits size) collect: [ :i | (i - 1) -> (logits at: i) ].
	^ ((pairs asSortedCollection: [ :a :b | a value > b value ]) first: k) collect: [ :a | a key ]
]

{ #category : 'support' }
GcGpt2InferenceExamples >> weightFootprintBytesOf: aModel [
	"Total resident bytes of a model's DECODED weight cache: 4 bytes per element for Float32Array (#f32 storage), 8 for Float64Array (#f64). The honest memory number -- the sum of the actual cached arrays after a forward."
	| total |
	total := 0.
	aModel weightCache valuesDo: [ :arr |
		total := total + (arr size * ((arr isKindOf: Float32Array) ifTrue: [ 4 ] ifFalse: [ 8 ])) ].
	^ total
]
