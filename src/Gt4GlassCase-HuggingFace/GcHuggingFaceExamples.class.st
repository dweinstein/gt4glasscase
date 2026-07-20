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

{ #category : 'examples - live' }
GcHuggingFaceExamples >> liveGpt2CorpusFingerprintFromMerges [
	"End to end on REAL gpt2: fetch the ordered BPE merge list (tokenizer.json preferred, ~1.4MB single GET), build the GcMergeList (50000 rules), and record empirical facts. Bounded ranged reads only (I5): one tokenizer.json GET.

	OBSERVED (2026-07, this run): gpt2 has exactly 50000 merges, ranks contiguous 0..49999. The FIRST learned merge is space+'t' -> Gt (U+0120 't'), category asciiLetter -- the single most frequent byte pair in gpt2's corpus. Produced-category totals: asciiLetter 46868, digit 1681, punctuation 746, otherNonAscii 704, whitespace 1, cjk 0 (gpt2 is overwhelmingly English/ASCII, almost no whitespace-run or CJK merges -- itself a fingerprint of an English web corpus). suspectedManualMerges (heuristic: low-rank + structurally odd) flags 4: '--'@182, '..'@236, the double-newline whitespace run @372, '----'@394 -- small, as expected for a learned tokenizer, with NO early space-run family (unlike Gemma)."
	<gtExample>
	<noTest>
	| source ml sp firstRule ranksOk suspects |
	source := GcHuggingFaceModelSource forRepository: 'openai-community/gpt2'.
	ml := source mergeList.
	self assert: ml size equals: 50000.
	ranksOk := (ml rules withIndexCollect: [ :r :i | r rank = (i - 1) ]) allSatisfy: [ :b | b ].
	self assert: ranksOk.
	self assert: (ml ruleAt: 0) rank equals: 0.
	self assert: (ml ruleAt: 49999) rank equals: 49999.
	sp := (Character value: 288) asString.
	firstRule := ml ruleAt: 0.
	self assert: firstRule left equals: sp.
	self assert: firstRule right equals: 't'.
	self assert: firstRule merged equals: sp , 't'.
	self assert: firstRule producedCategory equals: #asciiLetter.
	suspects := ml suspectedManualMerges.
	self assert: suspects size equals: 4.
	self assert: (suspects rules anySatisfy: [ :r | r isWhitespaceRun ]).
	self assert: (ml categoryCounts at: #asciiLetter) > 40000.
	self assert: (ml categoryCounts at: #cjk) equals: 0.
	self assert: (ml fingerprintChartElement isKindOf: BlElement).
	self assert: ml fingerprintChartElement children notEmpty.
	^ ml
]

{ #category : 'examples - signal flow' }
GcHuggingFaceExamples >> liveGpt2SignalFlowDetectsFusedAttention [
	"Load the real gpt2 metadata (config.json + safetensors header, KB-scale) through the adapter and derive the signal-flow wiring. gpt2 is the deliberate fused case: a single fused c_attn projection, no split q_proj. Returns the source so the diagram itself can be rendered."
	<gtExample>
	<noTest>
	| source flow |
	source := GcHuggingFaceModelSource forRepository: 'openai-community/gpt2'.
	flow := GcSignalFlow fromTensorGroup: source tensorGroup architecture: source architecture.
	self assert: flow attentionFused.
	self assert: flow modelStyleName equals: 'gpt2-style'.
	self assert: (flow nodeLabels includes: 'q_proj') not.
	self assert: (flow nodeLabels includes: 'c_attn').
	^ source
]

{ #category : 'examples - undertrained tokens' }
GcHuggingFaceExamples >> liveGpt2UndertrainedGlitchTokens [
	"End to end on REAL gpt2: fetch vocab.json + ONE 256-row control band + one embedding row per documented SolidGoldMagikarp-family glitch token, score them, and record the empirical result. Bounded ranged reads only (I5): vocab.json + ~0.8MB band + a few KB of rows.

	HONEST FINDING (2026-07, this run): against a naive ids-0-255 control band with a BAND-LOCAL centroid approximation, the documented glitch family does NOT separate as low-norm / near-centroid. Their median embedding L2 norm (~4.06) sits ABOVE the control-band median (~3.44), and their median suspicion score is low (~0.13). Real per-token norms: SolidGoldMagikarp 3.98, petertodd 4.01, TheNitromeFan 4.06, GoldMagikarp 4.56, EStream 5.15; control-band norm median 3.44 (min 2.69, max 5.34).
	The published 'tokens nearest the embedding centroid' result is a full-vocab-centroid statement; a 256-row band-local mean is too biased to reproduce it -- which is exactly why the detector labels its centroid an approximation (centroidBasisLabel). A representative / full-vocab centroid basis is follow-up work (DW-18+). This example proves the pipeline on real weights and asserts the negative result rather than a separation that is not there."
	<gtExample>
	<noTest>
	| source glitchIds scan median glitchMedianNorm controlMedianNorm glitchMedianScore magikarp |
	source := GcHuggingFaceModelSource forRepository: 'openai-community/gpt2'.
	glitchIds := #(43453 37444 39906 42090 42202).
	scan := source undertrainedScanForCandidateIds: glitchIds controlBandStart: 0 controlBandSize: 256.
	"structural facts on real data"
	self assert: scan tied.
	self assert: scan embeddingRef name equals: 'wte.weight'.
	self assert: scan embeddingRef dtype equals: #f32.
	self assert: scan candidates size equals: 5.
	self assert: scan controlBandSize equals: 256.
	"id -> text decoding matches the real tokenizer (byte-level-BPE space renders as U+0120)"
	magikarp := scan candidates detect: [ :ut | ut tokenId = 43453 ].
	self assert: (magikarp text includesSubstring: 'SolidGoldMagikarp').
	"machinery runs on real weights: every candidate scored, finite, in [0,1]"
	self assert: (scan candidates allSatisfy: [ :ut | ut embeddingNorm isFinite and: [ ut score between: 0 and: 1 ] ]).
	"HONEST empirical result: NO low-norm / near-centroid separation vs an ids-0-255 band-local centroid"
	median := [ :coll | | s | s := coll asSortedCollection asArray. s at: (s size + 1) // 2 ].
	glitchMedianNorm := median value: (scan candidates collect: [ :ut | ut embeddingNorm ]).
	controlMedianNorm := median value: scan controlNorms.
	glitchMedianScore := median value: (scan candidates collect: [ :ut | ut score ]).
	self assert: glitchMedianNorm > controlMedianNorm.
	self assert: glitchMedianScore < (1 / 2).
	"views render on real data"
	self assert: (scan scatterElement isKindOf: BlElement).
	self assert: scan scatterElement children notEmpty.
	^ scan
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

{ #category : 'examples - live' }
GcHuggingFaceExamples >> liveLayerValueDriftCurveHasEnoughPoints [
	"Warm the cheapest per-layer cohort of SmolLM2-135M over bounded HTTP Range fetches (I5), then confirm the layer group's sampled-value drift curve has >= 25 measured layer points -- a real value curve across depth, not structural. Returns the layers GcLayerGroup."
	<gtExample>
	<noTest>
	| file group module warmed layers points |
	file := self source safetensorsFileFor: self repositoryId file: 'model.safetensors'.
	group := file tensorGroup.
	module := group defaultWarmModule.
	self assert: module notNil.
	warmed := group warmStatsForModule: module.
	self assert: warmed > 0.
	layers := group layers.
	points := layers perLayerCurvePoints: [ :layer | layers sampledMeanForLayer: layer ].
	self assert: points size >= 25.
	^ layers
]

{ #category : 'examples - live' }
GcHuggingFaceExamples >> liveModelSourceComparison [
	"Group three real, differently-named small public models, load their metadata over bounded HTTP (config.json + safetensors header only -- I5), and prove the comparison holds: one architecture column per model, model_type among the differing config knobs, and near-zero tensor-name overlap between the llama-style and gpt2-style checkpoints."
	<gtExample>
	<noTest>
	| sources group |
	sources := #('HuggingFaceTB/SmolLM2-135M' 'Qwen/Qwen2.5-0.5B' 'openai-community/gpt2')
		collect: [ :repo | GcHuggingFaceModelSource forRepository: repo ].
	group := GcModelSourceGroup withAll: sources.
	group loadMetadata.
	self assert: group loadedCount equals: 3.
	self assert: group architectureComparison labels size equals: 3.
	self assert: (group architectureComparison architectures allSatisfy: [ :arch | arch numLayers > 0 ]).
	self assert: (group configDiffKeys includes: 'model_type').
	self assert: group sharedTensorNames size < 5.
	^ group
]

{ #category : 'examples - live' }
GcHuggingFaceExamples >> liveQwen25SignalFlowIsHomogeneous [
	"Qwen/Qwen2.5-7B-Instruct: a homogeneous single-tower transformer -> exactly one archetype (a faithful, not merely representative, diagram) with real dims. Headers only (I5)."
	<gtExample>
	<noTest>
	| source flow |
	source := GcHuggingFaceModelSource forRepository: 'Qwen/Qwen2.5-7B-Instruct'.
	flow := GcSignalFlow fromTensorGroup: source tensorGroup architecture: source architecture.
	self assert: flow archetypeCount equals: 1.
	self assert: flow isHomogeneous.
	self assert: flow modelStyleName equals: 'llama-style'.
	self assert: (flow nodeLabels includes: 'q_proj').
	self assert: flow towers size equals: 1.
	^ flow
]

{ #category : 'examples - sharded' }
GcHuggingFaceExamples >> liveQwen25_7bShardedUnion [
	"Load Qwen/Qwen2.5-7B-Instruct (4 standard-named shards) as a sharded union via HTTP Range HEADERS only -- no weights downloaded (I5). Assert union tensor count == the distinct weight_map key count, and that >= 2 distinct shard files are represented among the tensors."
	<gtExample>
	<noTest>
	| source union index weightMap shardFiles |
	source := GcHuggingFaceModelSource forRepository: 'Qwen/Qwen2.5-7B-Instruct'.
	union := source safetensorsFile.
	self assert: (union isKindOf: GcShardedSafetensorsFile).
	index := source client safetensorsIndex: 'Qwen/Qwen2.5-7B-Instruct'.
	weightMap := index at: 'weight_map'.
	self assert: union tensorCount equals: weightMap size.
	self assert: union shardCount >= 4.
	shardFiles := (union tensors collect: [ :t | t file fileName ]) asSet.
	self assert: shardFiles size >= 2.
	^ union
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

{ #category : 'examples - live' }
GcHuggingFaceExamples >> liveSmolLm2SignalFlowSingleArchetype [
	"HuggingFaceTB/SmolLM2-135M (single-file): still one archetype spanning all 30 layers -- the previously-correct homogeneous case stays faithful. Headers only (I5)."
	<gtExample>
	<noTest>
	| source flow |
	source := GcHuggingFaceModelSource forRepository: 'HuggingFaceTB/SmolLM2-135M'.
	flow := GcSignalFlow fromTensorGroup: source tensorGroup architecture: source architecture.
	self assert: flow archetypeCount equals: 1.
	self assert: flow isHomogeneous.
	self assert: flow mainTower layerCount equals: 30.
	self assert: flow modelStyleName equals: 'llama-style'.
	^ flow
]

{ #category : 'examples - sharded' }
GcHuggingFaceExamples >> liveSmolLm2SingleFileRegression [
	"Regression: a single-file model still resolves to a plain GcSafetensorsFile (fast path, NOT a sharded union) -- 272 tensors, unchanged. Headers only (I5)."
	<gtExample>
	<noTest>
	| source file |
	source := GcHuggingFaceModelSource forRepository: 'HuggingFaceTB/SmolLM2-135M'.
	file := source safetensorsFile.
	self assert: (file isKindOf: GcShardedSafetensorsFile) not.
	self assert: (file isKindOf: GcSafetensorsFile).
	self assert: file tensorCount equals: 272.
	^ file
]

{ #category : 'examples - sharded' }
GcHuggingFaceExamples >> liveTSearchShardedUnion [
	"t-tech/T-Search: odd-stem numbered shards (model.safetensors-NNNNN-of-.. with .safetensors mid-name) PLUS an unnumbered model-mtp.safetensors MTP head. model.safetensors alone 404s; the naming-agnostic union (shard list = unique weight_map values) loads all files. Assert it now loads, spans 15 files, and includes the odd mtp extra. Headers only (I5)."
	<gtExample>
	<noTest>
	| source union |
	source := GcHuggingFaceModelSource forRepository: 't-tech/T-Search'.
	union := source safetensorsFile.
	self assert: (union isKindOf: GcShardedSafetensorsFile).
	self assert: union shardCount >= 15.
	self assert: (union shards anySatisfy: [ :sh | sh fileName includesSubstring: 'mtp' ]).
	self assert: union tensorCount > 100.
	^ union
]

{ #category : 'examples - live' }
GcHuggingFaceExamples >> liveTSearchSignalFlowSegmentsTowers [
	"t-tech/T-Search (a Qwen3.5-MoE vision-language model): the signal flow segments the LANGUAGE tower into its 2 distinct archetypes -- 30 linear-attention/SSM layers and 10 full softmax-attention layers, all MoE -- WITHOUT conflating conv1d with q_proj. The VISION tower and the MTP head are each drawn as their own separate strand (not merged into the language block), and the embedding dims are read from the real tensor shape (fixing the old bogus 2048x2048). Ground truth is the live weight_map, which corrects the design brief (2 archetypes, not 3; there is no separate hybrid layer). Fetches the index + shard headers only (I5). Returns the flow for rendering."
	<gtExample>
	<noTest>
	| source flow main lin split labels vision mtp |
	source := GcHuggingFaceModelSource forRepository: 't-tech/T-Search'.
	flow := GcSignalFlow fromTensorGroup: source tensorGroup.
	main := flow mainTower.
	self assert: main name equals: 'language'.
	self assert: main archetypeCount equals: 2.
	lin := main archetypes detect: [ :a | a attentionKind = #linear ].
	split := main archetypes detect: [ :a | a attentionKind = #split ].
	self assert: (main archetypes allSatisfy: [ :a | a isMoE ]).
	self assert: (lin attentionTensors anySatisfy: [ :t | (lin moduleLeafOf: t) = 'conv1d' ]).
	self assert: (lin attentionTensors anySatisfy: [ :t | (lin moduleLeafOf: t) = 'q_proj' ]) not.
	self assert: (split attentionTensors anySatisfy: [ :t | (split moduleLeafOf: t) = 'q_proj' ]).
	self assert: (split attentionTensors anySatisfy: [ :t | (split moduleLeafOf: t) = 'conv1d' ]) not.
	vision := flow auxiliaryTowers detect: [ :t | t name = 'vision' ].
	self assert: vision layerCount > 20.
	mtp := flow auxiliaryTowers detect: [ :t | t name = 'mtp' ].
	self assert: mtp layerCount equals: 1.
	labels := flow nodeLabels.
	self assert: (labels includes: 'vision tower').
	self assert: (labels includes: 'mtp tower').
	self assert: (labels includes: 'mtp head').
	self assert: (labels includes: 'conv1d').
	self assert: (labels includes: 'q_proj').
	self assert: ((flow nodes detect: [ :n | n kind = #embedding and: [ n label = 'embed_tokens' ] ]) annotation includesSubstring: 'x 2048').
	self assert: flow isHomogeneous not.
	^ flow
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

{ #category : 'examples - live' }
GcHuggingFaceExamples >> liveWarmLayernormCohortLightsSkyline [
	"Warm one cheap per-layer cohort's Tier-1 stats over bounded HTTP Range fetches (e.g. ~30 layernorm vectors of SmolLM2-135M), then confirm at least one tensor now carries a value-metric (sampled-mean) regularity z-score -- the skyline's colour path is real, not just structural. No weights downloaded wholesale (I5)."
	<gtExample>
	<noTest>
	| file group module warmed valueScores |
	file := self source safetensorsFileFor: self repositoryId file: 'model.safetensors'.
	group := file tensorGroup.
	module := group defaultWarmModule.
	self assert: module notNil.
	warmed := group warmStatsForModule: module.
	self assert: warmed > 0.
	valueScores := group regularityScores values select: [ :s | s isValueMetric and: [ s hasCohort ] ].
	self assert: valueScores notEmpty.
	^ file
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
