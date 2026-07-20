"
Executable documentation for Glass Case. Invariant I9: every claim is a <gtExample>. Examples compose (a campaign example references artifact examples), so the dependency graph is explorable and the system is self-documenting; findings become examples and examples become the release-watch regression suite.
"
Class {
	#name : 'GcExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'examples - groups' }
GcExamples >> aggregateDistributionMergesSampledHistograms [
	<gtExample>
	"The aggregate distribution merges per-tensor histograms into one 40-bin histogram whose total count equals the pooled sample count, spanning the pooled value range [0, 10]."
	| hA hB group merged total |
	hA := (GcTensorStats fromValues: { 0.0. 0.0. 1.0. 1.0 }) histogram.
	hB := (GcTensorStats fromValues: { 9.0. 10.0. 10.0 }) histogram.
	group := GcTensorGroup new.
	merged := group mergeHistograms: { hA. hB } binCount: 40.
	self assert: merged size equals: 40.
	total := merged inject: 0 into: [ :acc :bin | acc + bin count ].
	self assert: total equals: 7.
	self assert: merged first lowerBound equals: 0.0.
	self assert: merged last upperBound equals: 10.0.
	^ merged
]

{ #category : 'examples - architecture compare' }
GcExamples >> architectureComparisonMarksDifference [
	<gtExample>
	| a b comparison rows layersRow |
	a := GcArchitecture new numLayers: 30; numHeads: 9; hiddenSize: 576; yourself.
	b := GcArchitecture new numLayers: 32; numHeads: 9; hiddenSize: 576; yourself.
	comparison := GcArchitectureComparison forAll: { 'base' -> a. 'finetune' -> b }.
	rows := comparison facetRows.
	layersRow := rows detect: [ :r | (r at: 1) = 'Layers' ].
	self assert: (layersRow at: 3) equals: false.
	self assert: comparison labels equals: #('base' 'finetune').
	^ comparison
]

{ #category : 'examples - dead weights' }
GcExamples >> architectureDeadWeightsCleanModel [
	<gtExample>
	| arch group analysis |
	arch := GcArchitecture new numLayers: 2; yourself.
	group := GcTensorGroup new.
	arch expectedTensorNames do: [ :n | group addItem: (GcTensorRef name: n dtype: #bf16 shape: #(4 4)) ].
	analysis := arch deadWeightAnalysisOn: group.
	self assert: (analysis at: #unreferenced) isEmpty.
	self assert: (analysis at: #missing) isEmpty.
	self assert: (analysis at: #matchedCount) equals: group size.
	^ analysis
]

{ #category : 'examples - dead weights' }
GcExamples >> architectureDeadWeightsFindsImplantAndMissing [
	<gtExample>
	| arch group analysis |
	arch := GcArchitecture new numLayers: 2; yourself.
	group := GcTensorGroup new.
	arch expectedTensorNames do: [ :n |
		n = 'model.norm.weight' ifFalse: [ group addItem: (GcTensorRef name: n dtype: #bf16 shape: #(4 4)) ] ].
	group addItem: (GcTensorRef name: 'model.layers.1.mlp.implant.weight' dtype: #bf16 shape: #(4 4)).
	analysis := arch deadWeightAnalysisOn: group.
	self assert: (analysis at: #unreferenced) size equals: 1.
	self assert: (analysis at: #unreferenced) first name equals: 'model.layers.1.mlp.implant.weight'.
	self assert: (analysis at: #missing) equals: { 'model.norm.weight' }.
	^ analysis
]

{ #category : 'examples-groups' }
GcExamples >> artifactGroupPartitionByPrecision [
	<gtExample>
	| group partitions |
	group := self artifactGroupThreePrecisions.
	partitions := group partitionBy: [ :a | a precision ].
	self assert: (partitions isKindOf: GcGroupOfGroups).
	self assert: partitions size equals: 3.
	self assert: (partitions items allSatisfy: [ :g | g isKindOf: GcArtifactGroup ]).
	^ partitions
]

{ #category : 'examples-groups' }
GcExamples >> artifactGroupSelectReturnsGroup [
	<gtExample>
	"I2 + I3: select: returns a same-species group that records how it was made."
	| group selected |
	group := self artifactGroupThreePrecisions.
	selected := group select: [ :a | a precision = #bf16 ].
	self assert: (selected isKindOf: GcArtifactGroup).
	self assert: selected size equals: 1.
	self assert: selected derivation operation equals: #select:.
	self assert: selected derivation parent == group.
	^ selected
]

{ #category : 'examples-groups' }
GcExamples >> artifactGroupThreePrecisions [
	<gtExample>
	| revision group |
	revision := self revisionQwen3_32b.
	group := GcArtifactGroup new.
	#(#bf16 #int8 #int4) do: [ :prec |
		group addItem: (GcModelArtifact revision: revision precision: prec) ].
	self assert: group size equals: 3.
	self assert: (group isKindOf: GcArtifactGroup).
	^ group
]

{ #category : 'examples-provenance' }
GcExamples >> artifactQwen3_32bBf16 [
	<gtExample>
	| artifact |
	artifact := GcModelArtifact
		revision: self revisionQwen3_32b
		precision: #bf16
		format: #safetensors
		location: 'hf://Qwen/Qwen3-32B'.
	self assert: artifact precision equals: #bf16.
	self assert: (artifact coordinate at: #precision) equals: #bf16.
	^ artifact
]

{ #category : 'examples-groups' }
GcExamples >> artifactSliceByPrecision [
	<gtExample>
	"varyingAxis: groups cohorts differing only along precision; the three artifacts share a revision so they form one cohort."
	| group slice |
	group := self artifactGroupThreePrecisions.
	slice := group varyingAxis: #precision.
	self assert: (slice isKindOf: GcSliceGroup).
	self assert: slice varyingAxis equals: #precision.
	self assert: slice cohorts size equals: 1.
	self assert: slice cohorts anyOne size equals: 3.
	^ slice
]

{ #category : 'examples - coverage' }
GcExamples >> campaignPlanCoverage [
	<gtExample>
	| coords plan campaign |
	coords := OrderedCollection new.
	#(bf16 int8) do: [ :prec |
		#(p1 p2) do: [ :probe |
			coords add: (GcCoordinate new at: #precision put: prec; at: #probe put: probe; yourself) ] ].
	plan := GcCampaignPlan new plannedCoordinates: coords; yourself.
	campaign := GcCampaign new name: 'pilot'; plan: plan; yourself.
	self assert: campaign plannedCoordinates size equals: 4.
	self assert: campaign printString equals: 'campaign pilot (4 planned coordinates)'.
	^ campaign
]

{ #category : 'examples - small multiples' }
GcExamples >> comparisonSideBySideRows [
	<gtExample>
	| comparison rows |
	comparison := self groupComparisonSharedAndUnique.
	rows := comparison sideBySideRows.
	self assert: (rows first at: 1) equals: 'Items'.
	self assert: ((rows second at: 5) isKindOf: GcGroup).
	self assert: (rows second at: 5) size equals: 1.
	^ rows
]

{ #category : 'examples' }
GcExamples >> comparisonSwapMirrorsSides [
	<gtExample>
	| comparison swapped |
	comparison := self groupComparisonSharedAndUnique.
	swapped := GcGroupComparison left: comparison right right: comparison left.
	self assert: swapped left == comparison right.
	self assert: swapped right == comparison left.
	self assert: swapped onlyInLeft size equals: comparison onlyInRight size.
	self assert: swapped onlyInRight size equals: comparison onlyInLeft size.
	self assert: swapped inBoth size equals: comparison inBoth size.
	^ swapped
]

{ #category : 'examples-groups' }
GcExamples >> completionGroupSampleIsReproducible [
	<gtExample>
	"A seeded sample is reproducible and records its seed on the derivation (I3)."
	| group sampleA sampleB |
	group := GcCompletionGroup new.
	1 to: 10 do: [ :i |
		group addItem: (GcCompletion run: nil text: 'completion ', i printString) ].
	sampleA := group sample: 3 seed: 7.
	sampleB := group sample: 3 seed: 7.
	self assert: sampleA size equals: 3.
	self assert: (sampleA items collect: [ :c | c text ]) equals: (sampleB items collect: [ :c | c text ]).
	self assert: (sampleA derivation parameterAt: #seed) equals: 7.
	^ sampleA
]

{ #category : 'examples - groups' }
GcExamples >> completionGroupWithOutcomes [
	<gtExample>
	"A synthetic completion group of 40 completions with varied token lengths and clean/truncated stops, for the verdict-rate and length-distribution views. Hermetic (I9): 30 clean stops of 40 -> a 0.75 clean-stop rate."
	| group rate |
	group := GcCompletionGroup new.
	1 to: 40 do: [ :i |
		group addItem: (GcCompletion new
			run: nil;
			text: 'completion ' , i printString;
			tokenIds: (1 to: (5 + (i \\ 20))) asArray;
			stopReason: (i \\ 4 = 0 ifTrue: [ #length ] ifFalse: [ #stop ]);
			yourself) ].
	self assert: group size equals: 40.
	rate := group verdictRateBy: [ :c | c stopReason = #stop ].
	self assert: rate successes equals: 30.
	self assert: (rate proportion closeTo: 0.75).
	^ group
]

{ #category : 'examples-hypercube' }
GcExamples >> coordinateHoldsAxes [
	<gtExample>
	| coord reduced |
	coord := GcCoordinate new
		at: #precision put: #bf16;
		at: #seed put: 0;
		yourself.
	reduced := coord withoutAxis: #seed.
	self assert: reduced axes equals: #(#precision).
	^ coord
]

{ #category : 'examples - tensor numerics' }
GcExamples >> dtypeDecoderBf16KnownValues [
	<gtExample>
	| decoder |
	self assert: (GcDtypeDecoder bf16FromU16: 16r3F80) equals: 1.0.
	self assert: (GcDtypeDecoder bf16FromU16: 16rC000) equals: -2.0.
	decoder := GcDtypeDecoder forDtype: #bf16.
	self assert: (decoder decodeBytes: #[16r80 16r3F 16r00 16rC0]) equals: { 1.0. -2.0 }.
	self assert: decoder bytesPerElement equals: 2.
	^ decoder
]

{ #category : 'examples - tensor numerics' }
GcExamples >> dtypeDecoderF16KnownValues [
	<gtExample>
	| decoder |
	self assert: (GcDtypeDecoder f16FromU16: 16r3C00) equals: 1.0.
	self assert: (GcDtypeDecoder f16FromU16: 16r4000) equals: 2.0.
	self assert: (GcDtypeDecoder f16FromU16: 16rC000) equals: -2.0.
	self assert: (GcDtypeDecoder f16FromU16: 16r0001) equals: (2 raisedTo: -24) asFloat.
	self assert: (GcDtypeDecoder f16FromU16: 16r7C00) isInfinite.
	self assert: (GcDtypeDecoder f16FromU16: 16r7C00) positive.
	self assert: (GcDtypeDecoder f16FromU16: 16rFC00) isInfinite.
	self assert: (GcDtypeDecoder f16FromU16: 16rFC00) negative.
	self assert: (GcDtypeDecoder f16FromU16: 16r7E00) isNaN.
	decoder := GcDtypeDecoder forDtype: #f16.
	self assert: (decoder decodeBytes: #[16r00 16r3C 16r00 16r40]) equals: { 1.0. 2.0 }.
	^ decoder
]

{ #category : 'examples - tensor numerics' }
GcExamples >> dtypeDecoderF32KnownValues [
	<gtExample>
	| decoder |
	self assert: (GcDtypeDecoder f32FromU32: 16r3F800000) equals: 1.0.
	self assert: (GcDtypeDecoder f32FromU32: 16rC0000000) equals: -2.0.
	decoder := GcDtypeDecoder forDtype: #f32.
	self assert: (decoder decodeBytes: #[16r00 16r00 16r80 16r3F 16r00 16r00 16r00 16rC0]) equals: { 1.0. -2.0 }.
	self assert: decoder bytesPerElement equals: 4.
	^ decoder
]

{ #category : 'fixtures - embeddings' }
GcExamples >> f32LeBytes: aFloat [
	"Little-endian IEEE-754 f32 encoding of aFloat as 4 bytes -- the inverse of GcDtypeDecoder>>f32FromU32:, for building synthetic tensor buffers."
	| w |
	w := aFloat asIEEE32BitWord.
	^ ByteArray
		with: (w bitAnd: 16rFF)
		with: ((w bitShift: -8) bitAnd: 16rFF)
		with: ((w bitShift: -16) bitAnd: 16rFF)
		with: ((w bitShift: -24) bitAnd: 16rFF)
]

{ #category : 'examples-provenance' }
GcExamples >> fileDigestConfigJson [
	<gtExample>
	| digest |
	digest := GcFileDigest path: 'config.json' size: 812 sha256: 'aaaa1111bbbb2222'.
	self assert: digest shortSha256 equals: 'aaaa1111bbbb'.
	^ digest
]

{ #category : 'examples - groups' }
GcExamples >> findingGroupStatusBoard [
	<gtExample>
	"A synthetic finding group with mixed statuses renders a grouped status board (findings here are stubbed to just status + replications, which is all a status board needs)."
	| group byStatus |
	group := GcFindingGroup new.
	group addItem: (GcFinding status: #open replications: 0).
	group addItem: (GcFinding status: #open replications: 1).
	group addItem: (GcFinding status: #replicated replications: 5).
	group addItem: (GcFinding status: #refuted replications: 2).
	self assert: group size equals: 4.
	byStatus := group groupedBy: [ :f | f status ].
	self assert: (byStatus at: #open) size equals: 2.
	self assert: (byStatus at: #replicated) size equals: 1.
	^ group
]

{ #category : 'examples-groups' }
GcExamples >> groupComparisonSharedAndUnique [
	<gtExample>
	| revision a b c left right comparison |
	revision := self revisionQwen3_32b.
	a := GcModelArtifact revision: revision precision: #bf16.
	b := GcModelArtifact revision: revision precision: #int8.
	c := GcModelArtifact revision: revision precision: #int4.
	left := GcArtifactGroup withAll: { a. b }.
	right := GcArtifactGroup withAll: { b. c }.
	comparison := left compareTo: right.
	self assert: comparison inBoth size equals: 1.
	self assert: comparison onlyInLeft size equals: 1.
	self assert: comparison onlyInRight size equals: 1.
	^ comparison
]

{ #category : 'examples-groups' }
GcExamples >> groupDerivationChain [
	<gtExample>
	"Lineage is never broken (I3): chained operations are walkable back to the root."
	| group leaf |
	group := self artifactGroupThreePrecisions.
	leaf := (group select: [ :a | a precision ~= #int4 ]) select: [ :a | a precision = #bf16 ].
	self assert: leaf derivationChain equals: (OrderedCollection withAll: #(#select: #select:)).
	^ leaf
]

{ #category : 'examples - groups' }
GcExamples >> groupOfGroupsOverviewSendsInnerGroups [
	<gtExample>
	"Group-of-groups overview: partition a tensor group by module and confirm each row's object is the inner GROUP (recursive drill-down), each carrying a headline params number; the overview view resolves."
	| group view firstInner |
	group := self tensorGroupPartitionByModule.
	self assert: (group isKindOf: GcGroupOfGroups).
	self assert: group size equals: 3.
	group items do: [ :inner | self assert: (inner isKindOf: GcGroup) ].
	firstInner := group items first.
	self assert: (firstInner headline includesSubstring: 'params').
	view := group gtOverviewFor: GtPhlowView empty.
	self assert: view notNil.
	^ group
]

{ #category : 'examples-groups' }
GcExamples >> groupOutliersByByteSize [
	<gtExample>
	"outliersBy: keeps only items more than 2 std devs from the mean, lineage preserved."
	| group sizes outliers |
	group := GcTensorGroup new.
	sizes := #(100 110 105 95 100 108 97 103 102 1000000).
	sizes doWithIndex: [ :sz :i |
		| t |
		t := GcTensorRef name: ('model.layers.0.mlp.w', i printString, '.weight') dtype: #bf16 shape: #(1).
		t beginOffset: 0.
		t endOffset: sz.
		group addItem: t ].
	outliers := group outliersBy: [ :t | t byteSize ].
	self assert: outliers size equals: 1.
	self assert: (outliers isKindOf: GcTensorGroup).
	^ outliers
]

{ #category : 'examples - small multiples' }
GcExamples >> groupSmallMultiplesRendersCohorts [
	<gtExample>
	| partitions stencil context cell |
	partitions := self tensorGroupPartitionByModule.
	stencil := GcCohortStencil default.
	context := stencil contextFor: partitions.
	self assert: (context at: #max) >= 1.0.
	cell := stencil elementFor: partitions items first context: context.
	self assert: (cell isKindOf: BlElement).
	^ partitions
]

{ #category : 'examples - groups' }
GcExamples >> groupUniversalTrioResolvesForEverySubclass [
	<gtExample>
	"Acceptance (DW-17): every GcGroup subclass answers the universal trio -- items, statistics and derivation -- on an EMPTY instance without raising, each yielding a real (non-empty) view, and the underlying data paths are empty-safe."
	| selectors subclasses |
	selectors := #(gtItemsFor: gtStatisticsFor: gtDerivationFor:).
	subclasses := GcGroup allSubclasses.
	self assert: subclasses notEmpty.
	subclasses do: [ :cls |
		| inst |
		inst := cls new.
		self assert: inst items isEmpty.
		self assert: inst statistics notNil.
		self assert: inst derivations isEmpty.
		selectors do: [ :sel |
			| view |
			view := inst perform: sel with: GtPhlowView empty.
			self assert: view notNil.
			self assert: (view isKindOf: GtPhlowEmptyView) not ] ].
	^ subclasses
]

{ #category : 'examples - groups' }
GcExamples >> layerCurveViewRendersWithPlantedDrift [
	<gtExample>
	"The per-layer structural curve has exactly one point per layer and surfaces a planted per-layer drift: layer 5 carries an oversized q_proj, so its total-params point is the series maximum. The composed view element is non-empty and the gtView resolves."
	| group layerGroup points maxPoint element view |
	group := GcTensorGroup new.
	0 to: 7 do: [ :i |
		group addItem: (GcTensorRef
			name: 'model.layers.' , i printString , '.self_attn.q_proj.weight'
			dtype: #bf16
			shape: (i = 5 ifTrue: [ #(256 256) ] ifFalse: [ #(64 64) ])).
		group addItem: (GcTensorRef name: 'model.layers.' , i printString , '.self_attn.k_proj.weight' dtype: #bf16 shape: #(64 64)).
		group addItem: (GcTensorRef name: 'model.layers.' , i printString , '.self_attn.v_proj.weight' dtype: #bf16 shape: #(64 64)) ].
	layerGroup := group layers.
	self assert: layerGroup size equals: 8.
	points := layerGroup perLayerCurvePoints: [ :layer | layer totalParams ].
	self assert: points size equals: 8.
	maxPoint := points detectMax: [ :p | p at: #value ].
	self assert: (maxPoint at: #layer) index equals: 5.
	element := layerGroup curveElementForPoints: points valueTitle: 'Total params' subtitle: 'test'.
	self assert: (element isKindOf: BlElement).
	self assert: element children size >= 2.
	view := layerGroup gtPerLayerStructuralCurveFor: GtPhlowView empty.
	self assert: view notNil.
	^ layerGroup
]

{ #category : 'examples-provenance' }
GcExamples >> manifestDriftDetectsTampering [
	<gtExample>
	| clean tampered drift |
	clean := self manifestQwen3.
	tampered := GcRepoManifest revision: self revisionQwen3_32b.
	tampered addFile: (GcFileDigest path: 'config.json' size: 812 sha256: 'aaaa1111bbbb2222').
	tampered addFile: (GcFileDigest path: 'model.safetensors.index.json' size: 42318 sha256: 'deadbeefdeadbeef').
	drift := clean driftFrom: tampered.
	self assert: drift size equals: 1.
	self assert: drift first path equals: 'model.safetensors.index.json'.
	^ drift
]

{ #category : 'examples-provenance' }
GcExamples >> manifestDriftIsEmpty [
	<gtExample>
	| a b |
	a := self manifestQwen3.
	b := self manifestQwen3.
	self assert: (a driftFrom: b) isEmpty.
	^ a
]

{ #category : 'examples - manifest drift' }
GcExamples >> manifestDriftReportFindsSilentReupload [
	<gtExample>
	| clean tampered report |
	clean := self manifestQwen3.
	tampered := GcRepoManifest revision: self revisionQwen3_32b.
	tampered addFile: (GcFileDigest path: 'config.json' size: 812 sha256: 'aaaa1111bbbb2222').
	tampered addFile: (GcFileDigest path: 'model.safetensors.index.json' size: 42318 sha256: 'deadbeefdeadbeef').
	report := tampered driftReportFrom: clean.
	self assert: report isClean not.
	self assert: report changedFiles size equals: 1.
	self assert: report addedFiles isEmpty.
	self assert: report removedFiles isEmpty.
	^ report
]

{ #category : 'examples - manifest drift' }
GcExamples >> manifestDriftReportIsCleanForIdenticalSnapshots [
	<gtExample>
	| report |
	report := self manifestQwen3 driftReportFrom: self manifestQwen3.
	self assert: report isClean.
	self assert: report printString equals: 'clean drift (2 files)'.
	^ report
]

{ #category : 'examples-provenance' }
GcExamples >> manifestQwen3 [
	<gtExample>
	| manifest |
	manifest := GcRepoManifest revision: self revisionQwen3_32b.
	manifest addFile: (GcFileDigest path: 'config.json' size: 812 sha256: 'aaaa1111bbbb2222').
	manifest addFile: (GcFileDigest path: 'model.safetensors.index.json' size: 42318 sha256: 'cccc3333dddd4444').
	self assert: manifest fileCount equals: 2.
	self assert: manifest totalSize equals: 43130.
	^ manifest
]

{ #category : 'examples-provenance' }
GcExamples >> modelFamilyQwen3 [
	<gtExample>
	| family |
	family := GcModelFamily name: 'Qwen3-32B' publisher: 'Alibaba'.
	self assert: family name equals: 'Qwen3-32B'.
	^ family
]

{ #category : 'examples - model source comparison' }
GcExamples >> modelSourceComparisonArchitecture [
	"The Architecture comparison forwards to GcArchitectureComparison: one column per model, differing facets marked."
	<gtExample>
	| group comparison layersRow |
	group := self modelSourceComparisonGroup.
	comparison := group architectureComparison.
	self assert: comparison labels size equals: 2.
	self assert: comparison architectures size equals: 2.
	layersRow := comparison facetRows detect: [ :r | r first = 'Layers' ].
	self assert: (layersRow at: 3) equals: false.
	^ comparison
]

{ #category : 'examples - model source comparison' }
GcExamples >> modelSourceComparisonConfigDiff [
	"The config-diff finds EXACTLY the three planted differing knobs; the rest collapse into an identical-keys count."
	<gtExample>
	| group rows |
	group := self modelSourceComparisonGroup.
	self assert: group configDiffKeys asArray
		equals: #('num_hidden_layers' 'num_key_value_heads' 'rope_theta').
	rows := group configDiffRows.
	self assert: (rows first first) equals: '5 identical keys'.
	self assert: rows size equals: 4.
	^ rows
]

{ #category : 'examples - model source comparison' }
GcExamples >> modelSourceComparisonGroup [
	"compareWith: builds a species-correct, lineage-stamped GcModelSourceGroup of two model sources (I2 + I3)."
	<gtExample>
	| a b group |
	a := self stubModelSourceA.
	b := self stubModelSourceB.
	group := a compareWith: b.
	self assert: (group isKindOf: GcModelSourceGroup).
	self assert: group size equals: 2.
	self assert: group loadedCount equals: 2.
	self assert: group derivation operation equals: #compareWith:.
	self assert: (group derivation parameters at: #with) == b.
	self assert: ((group select: [ :each | true ]) isKindOf: GcModelSourceGroup).
	^ group
]

{ #category : 'examples - model source comparison' }
GcExamples >> modelSourceComparisonNamingOverlap [
	"Tensor-name overlap is exact on the planted names: A's 21 names are all shared, B adds 9 unique (its extra layer)."
	<gtExample>
	| group a b loaded |
	group := self modelSourceComparisonGroup.
	a := group items first.
	b := group items second.
	loaded := group items.
	self assert: group sharedTensorNames size equals: 21.
	self assert: (group uniqueTensorNamesFor: a among: loaded) size equals: 0.
	self assert: (group uniqueTensorNamesFor: b among: loaded) size equals: 9.
	^ group namingOverlapRows
]

{ #category : 'examples - model source comparison' }
GcExamples >> modelSourceComparisonSizeAndShape [
	"Size & shape rows read the planted architectures and tensor headers, formatting GQA vs MHA heads correctly."
	<gtExample>
	| group a b |
	group := self modelSourceComparisonGroup.
	a := group items first.
	b := group items second.
	self assert: (group configFacet: [ a loadedArchitecture numLayers ] of: a) equals: '2'.
	self assert: (group configFacet: [ b loadedArchitecture numLayers ] of: b) equals: '3'.
	self assert: (group headsDisplayFor: a) equals: '8/2 GQA'.
	self assert: (group headsDisplayFor: b) equals: '8 MHA'.
	self assert: (group tensorFacet: [ a loadedTensorGroup size ] of: a) equals: '21'.
	self assert: (group tensorFacet: [ b loadedTensorGroup size ] of: b) equals: '30'.
	^ group
]

{ #category : 'examples - model source comparison' }
GcExamples >> modelSourceComparisonViewsRender [
	"All comparison views render non-empty on a fully-loaded stub group, and render placeholders (not errors) when a member is UNLOADED -- render blocks read only cached state and never touch the missing metadata."
	<gtExample>
	| group viewSelectors unloaded mixed |
	group := self modelSourceComparisonGroup.
	viewSelectors := #(gtModelsFor: gtArchitectureComparisonFor: gtSizeAndShapeFor: gtParamBudgetFor: gtConfigDiffFor: gtNamingSchemeFor:).
	viewSelectors do: [ :sel |
		| view |
		view := group perform: sel with: GtPhlowView empty.
		self assert: view notNil.
		self assert: (view isKindOf: GtPhlowEmptyView) not ].
	unloaded := GcInMemoryModelSource new label: 'unloaded-stub'; yourself.
	mixed := GcModelSourceGroup withAll: { self stubModelSourceA. unloaded }.
	viewSelectors do: [ :sel |
		| view |
		view := mixed perform: sel with: GtPhlowView empty.
		self assert: view notNil.
		self assert: (view isKindOf: GtPhlowEmptyView) not ].
	self assert: mixed loadedCount equals: 1.
	self assert: (mixed configFacet: [ 1/0 ] of: unloaded) equals: 'not loaded'.
	self assert: (mixed tensorFacet: [ 1/0 ] of: unloaded) equals: 'not loaded'.
	self assert: (mixed headsDisplayFor: unloaded) equals: 'not loaded'.
	self assert: (mixed paramShareText: #attention of: unloaded) equals: 'not loaded'.
	self assert: (mixed configDiffRows isKindOf: Array).
	self assert: (mixed namingOverlapRows isKindOf: Array).
	self assert: (mixed architectureComparison facetRows isKindOf: Array).
	^ mixed
]

{ #category : 'examples-hypercube' }
GcExamples >> precisionAxis [
	<gtExample>
	| axis |
	axis := GcAxis
		named: #precision
		values: #(#bf16 #int8 #int4 #int3)
		ordering: #(#bf16 #int8 #int4 #int3).
	self assert: axis isOrdinal.
	self assert: (axis rankOf: #int4) equals: 3.
	^ axis
]

{ #category : 'examples-provenance' }
GcExamples >> provenanceQwen3 [
	<gtExample>
	| prov |
	prov := GcProvenance publisher: 'Alibaba' license: 'Apache-2.0'.
	prov announcementUrl: 'https://qwenlm.github.io/'.
	self assert: prov publisher equals: 'Alibaba'.
	^ prov
]

{ #category : 'examples - regularity' }
GcExamples >> regularityZScoreDetectsPlantedCohortAnomaly [
	"z-score math over a synthetic cohort of 10 q_proj.weight tensors (one per layer), all identical except a planted shape anomaly at layer 7. With 9 identical + 1 different, the planted member's population z is exactly sqrt(9) = 3 and each normal member's is -1/3, independent of the actual values -- so the anomaly is unmistakable and the maths is exact."
	<gtExample>
	| group scores planted normal |
	group := GcTensorGroup new.
	0 to: 9 do: [ :i |
		group addItem: (GcTensorRef
			name: 'model.layers.' , i printString , '.self_attn.q_proj.weight'
			dtype: #bf16
			shape: (i = 7 ifTrue: [ #(128 128) ] ifFalse: [ #(64 64) ])) ].
	scores := group regularityScores.
	planted := scores at: (group items detect: [ :t | t layerIndex = 7 ]).
	normal := scores at: (group items detect: [ :t | t layerIndex = 0 ]).
	self assert: planted isStructuralMetric.
	self assert: planted cohortSize equals: 10.
	self assert: (planted z closeTo: 3.0).
	self assert: planted absZ > 2.
	self assert: (normal z closeTo: -1 / 3).
	self assert: normal absZ < 0.5.
	self assert: planted hasCohort.
	^ group
]

{ #category : 'examples-provenance' }
GcExamples >> revisionQwen3_32b [
	<gtExample>
	| revision |
	revision := GcModelRevision
		repository: 'Qwen/Qwen3-32B'
		commit: 'a1b2c3d4e5'
		family: self modelFamilyQwen3.
	self assert: revision id equals: 'Qwen/Qwen3-32B@a1b2c3d4e5'.
	^ revision
]

{ #category : 'examples-provenance' }
GcExamples >> revisionWithProvenance [
	<gtExample>
	| revision |
	revision := self revisionQwen3_32b.
	revision provenance: self provenanceQwen3.
	self assert: revision provenance license equals: 'Apache-2.0'.
	^ revision
]

{ #category : 'examples - slack space' }
GcExamples >> safetensorsSlackGapAndOverlap [
	<gtExample>
	| h file ranges |
	h := Dictionary new.
	h at: 'a' put: (Dictionary new at: 'dtype' put: 'F32'; at: 'shape' put: #(2 2); at: 'data_offsets' put: #(0 16); yourself).
	h at: 'b' put: (Dictionary new at: 'dtype' put: 'F32'; at: 'shape' put: #(2 2); at: 'data_offsets' put: #(32 64); yourself).
	h at: 'c' put: (Dictionary new at: 'dtype' put: 'F32'; at: 'shape' put: #(2 2); at: 'data_offsets' put: #(48 80); yourself).
	file := GcSafetensorsFile new.
	file path: 'example-slack'.
	file parseHeaderDictionary: h.
	ranges := file slackRanges.
	self assert: ranges size equals: 2.
	self assert: ranges first kind equals: #gap.
	self assert: ranges first byteSize equals: 16.
	self assert: (ranges at: 2) kind equals: #overlap.
	^ file
]

{ #category : 'examples - slack space' }
GcExamples >> safetensorsTightFileHasNoSlack [
	<gtExample>
	| h file |
	h := Dictionary new.
	h at: 'a' put: (Dictionary new at: 'dtype' put: 'F32'; at: 'shape' put: #(2 2); at: 'data_offsets' put: #(0 16); yourself).
	h at: 'b' put: (Dictionary new at: 'dtype' put: 'F32'; at: 'shape' put: #(2 2); at: 'data_offsets' put: #(16 32); yourself).
	file := GcSafetensorsFile new.
	file path: 'example-tight'.
	file parseHeaderDictionary: h.
	self assert: file slackRanges isEmpty.
	^ file
]

{ #category : 'examples - signal flow' }
GcExamples >> signalFlowFromArchitectureIsInferredCanonical [
	"With only a config-derived GcArchitecture (no tensor names), the fallback draws the canonical llama-style wiring, marked inferred, with the GQA head split annotated from the config."
	<gtExample>
	| arch flow labels m |
	arch := GcArchitecture new numLayers: 4; numHeads: 9; kvHeads: 3; hiddenSize: 576; yourself.
	flow := GcSignalFlow fromArchitecture: arch.
	labels := flow nodeLabels.
	self assert: flow isInferred.
	self assert: (flow styleLabel includesSubstring: 'inferred').
	self assert: (flow attentionHeadNote includesSubstring: 'GQA').
	#('embed_tokens' 'input_layernorm' 'q_proj' 'o_proj' 'gate_proj' 'down_proj' 'lm_head')
		do: [ :each | self assert: (labels includes: each) ].
	self assert: flow residualEdgeCount equals: 2.
	m := GtMondrian new.
	flow paintSignalFlowOn: m.
	self assert: m root children notEmpty.
	^ flow
]

{ #category : 'examples - signal flow' }
GcExamples >> signalFlowFromGpt2FileShowsFusedAttention [
	"A GPT-2-style synthetic checkpoint (fused attn.c_attn, 2-proj MLP, tied output) -> signal-flow diagram: assert the FUSED attention node (c_attn) is present, that there is no split q_proj node, that the MLP is 2-proj, and that tied embeddings are detected."
	<gtExample>
	| file flow labels m |
	file := self syntheticGpt2FileNamed: 'synthetic-signalflow-gpt2-4L' layers: 4.
	flow := GcSignalFlow fromTensorGroup: file tensorGroup.
	labels := flow nodeLabels.
	self assert: flow attentionFused.
	self assert: flow mlpGated not.
	self assert: flow modelStyleName equals: 'gpt2-style'.
	self assert: (labels includes: 'c_attn').
	self assert: (labels includes: 'q_proj') not.
	self assert: (labels includes: 'c_fc').
	self assert: flow isTiedEmbeddings.
	self assert: flow residualEdgeCount equals: 2.
	m := GtMondrian new.
	flow paintSignalFlowOn: m.
	self assert: m root children notEmpty.
	^ flow
]

{ #category : 'examples - signal flow' }
GcExamples >> signalFlowFromLlamaFileRendersBlocks [
	"A llama-style synthetic checkpoint -> signal-flow diagram: assert the derived block set (embedding, split attention q/k/v/o, gated MLP gate/up/down, both norms, head) and the two residual bypass edges, and that the Mondrian renders non-empty."
	<gtExample>
	| file flow labels m |
	file := self syntheticModelFileNamed: 'synthetic-signalflow-6L' layers: 6 experts: 0.
	flow := GcSignalFlow fromTensorGroup: file tensorGroup.
	labels := flow nodeLabels.
	self assert: flow attentionFused not.
	self assert: flow mlpGated.
	self assert: flow modelStyleName equals: 'llama-style'.
	#('embed_tokens' 'input_layernorm' 'q_proj' 'k_proj' 'v_proj' 'o_proj' 'post_attention_layernorm' 'gate_proj' 'up_proj' 'down_proj' 'lm_head')
		do: [ :each | self assert: (labels includes: each) ].
	self assert: (flow nodes anySatisfy: [ :n | n kind = #finalNorm ]).
	self assert: flow residualEdgeCount equals: 2.
	m := GtMondrian new.
	flow paintSignalFlowOn: m.
	self assert: m root children notEmpty.
	^ flow
]

{ #category : 'examples - regularity' }
GcExamples >> skylineBuildsForMoeScaleModelWithinBudget [
	"Performance acceptance: a 61-layer MoE-scale header (~700+ tensors, generated programmatically) must build the skyline element hermetically in bounded time (< 3 s). Proves the issue's 'renders a 61-layer MoE without lag' claim without any network."
	<gtExample>
	| file group m ms |
	file := self syntheticModelFileNamed: 'synthetic-moe-61L' layers: 61 experts: 3.
	group := file tensorGroup.
	self assert: group size >= 700.
	ms := [ m := GtMondrian new. group paintSkylineOn: m. m root ] millisecondsToRun.
	self assert: m root children notEmpty.
	self assert: m root children size equals: 1 + group layers size.
	self assert: ms < 3000.
	^ file
]

{ #category : 'examples - regularity' }
GcExamples >> skylineRendersWithStructuralAnomaly [
	"Build a synthetic 6-layer safetensors file with a planted structural anomaly (one q_proj with an off shape), then paint the skyline and assert it renders: one caption node plus one row per depth (bands + layers), and the planted tensor's |z| exceeds 2 via the structural metric."
	<gtExample>
	| header info begin file group m planted expected |
	header := self syntheticModelHeaderLayers: 6 experts: 0.
	info := header at: 'model.layers.3.self_attn.q_proj.weight'.
	begin := (info at: 'data_offsets') first.
	info at: 'shape' put: #(64 320).
	info at: 'data_offsets' put: { begin. begin + (64 * 320 * 2) }.
	file := GcSafetensorsFile new.
	file path: 'synthetic-anomaly-6L'.
	file parseHeaderDictionary: header.
	group := file tensorGroup.
	m := GtMondrian new.
	group paintSkylineOn: m.
	self assert: m root children notEmpty.
	expected := 1 + group layers size.
	self assert: m root children size equals: expected.
	planted := group items detect: [ :t | t name = 'model.layers.3.self_attn.q_proj.weight' ].
	self assert: (group regularityScoreFor: planted) absZ > 2.
	self assert: (group regularityScoreFor: planted) isStructuralMetric.
	^ file
]

{ #category : 'examples - model source comparison' }
GcExamples >> stubModelSourceA [
	"A hermetic in-memory model source: a 2-layer GQA (8/2) llama-style stub with a matching synthetic safetensors header (21 tensors). No network."
	<gtExample>
	| config file source |
	config := GcModelConfig fromDictionary: (Dictionary new
		at: 'model_type' put: 'llama';
		at: 'hidden_size' put: 64;
		at: 'num_attention_heads' put: 8;
		at: 'num_key_value_heads' put: 2;
		at: 'num_hidden_layers' put: 2;
		at: 'vocab_size' put: 32000;
		at: 'intermediate_size' put: 128;
		at: 'rope_theta' put: 10000;
		yourself).
	file := self syntheticModelFileNamed: 'stub-a/model.safetensors' layers: 2 experts: 0.
	source := GcInMemoryModelSource named: 'stub-a' config: config safetensorsFile: file.
	self assert: source isMetadataLoaded.
	self assert: source loadedArchitecture numLayers equals: 2.
	self assert: source loadedTensorGroup size equals: 21.
	^ source
]

{ #category : 'examples - model source comparison' }
GcExamples >> stubModelSourceB [
	"A hermetic in-memory model source: a 3-layer MHA (8/8) llama-style stub differing from stub A on exactly three config knobs (layers, kv-heads, rope_theta) and one extra transformer layer (30 tensors). No network."
	<gtExample>
	| config file source |
	config := GcModelConfig fromDictionary: (Dictionary new
		at: 'model_type' put: 'llama';
		at: 'hidden_size' put: 64;
		at: 'num_attention_heads' put: 8;
		at: 'num_key_value_heads' put: 8;
		at: 'num_hidden_layers' put: 3;
		at: 'vocab_size' put: 32000;
		at: 'intermediate_size' put: 128;
		at: 'rope_theta' put: 50000;
		yourself).
	file := self syntheticModelFileNamed: 'stub-b/model.safetensors' layers: 3 experts: 0.
	source := GcInMemoryModelSource named: 'stub-b' config: config safetensorsFile: file.
	self assert: source isMetadataLoaded.
	self assert: source loadedArchitecture numLayers equals: 3.
	self assert: source loadedTensorGroup size equals: 30.
	^ source
]

{ #category : 'fixtures - embeddings' }
GcExamples >> syntheticEmbeddingFileVocab: vocab hidden: hidden plantedIds: plantedIds [
	"A hermetic synthetic embedding safetensors file: a single vocab x hidden f32 'wte.weight' tensor wired to an in-memory bytes provider, so real tensor bytes decode through the sampling path with no network. Planted ids are the undertrained plants (tiny norm, near the centroid)."
	| buf header file |
	buf := ByteArray new.
	0 to: vocab - 1 do: [ :i |
		(self syntheticEmbeddingRowVocab: vocab hidden: hidden id: i plantedIds: plantedIds)
			do: [ :f | buf := buf , (self f32LeBytes: f) ] ].
	header := Dictionary new.
	header at: 'wte.weight' put: (Dictionary new
		at: 'dtype' put: 'F32';
		at: 'shape' put: { vocab. hidden };
		at: 'data_offsets' put: { 0. buf size };
		yourself).
	file := GcSafetensorsFile new.
	file path: 'synthetic/embedding.safetensors'.
	file parseHeaderDictionary: header.
	file byteDataOffset: 0.
	file bytesProvider: (GcInMemoryBytesProvider bytes: buf dataOffset: 0).
	^ file
]

{ #category : 'fixtures - embeddings' }
GcExamples >> syntheticEmbeddingRowVocab: vocab hidden: hidden id: i plantedIds: plantedIds [
	"Row i of the synthetic embedding: planted ids are near-zero (tiny norm, near the centroid); every other row has unit entries (+/-1 by bit pattern of i) so its L2 norm is exactly sqrt(hidden) and the cloud spreads around a nonzero centroid."
	| row |
	(plantedIds includes: i) ifTrue: [
		row := Array new: hidden withAll: 0.0.
		row at: 1 put: 0.03125.
		^ row ].
	^ (1 to: hidden) collect: [ :j |
		(i bitAnd: (1 bitShift: (j - 1))) = 0 ifTrue: [ 1.0 ] ifFalse: [ -1.0 ] ]
]

{ #category : 'fixtures' }
GcExamples >> syntheticGpt2FileNamed: aString layers: nLayers [
	| file |
	file := GcSafetensorsFile new.
	file path: aString.
	file parseHeaderDictionary: (self syntheticGpt2HeaderLayers: nLayers).
	^ file
]

{ #category : 'fixtures' }
GcExamples >> syntheticGpt2HeaderLayers: nLayers [
	"A plain safetensors header for a synthetic GPT-2-style checkpoint: FUSED attention (attn.c_attn), 2-proj MLP (mlp.c_fc / mlp.c_proj), wte/wpe embeddings, ln_1/ln_2/ln_f norms, and tied output (no lm_head tensor). Exercises the fused-attention branch of the signal-flow derivation with no network."
	| header hidden offset add |
	header := Dictionary new.
	hidden := 64.
	offset := 0.
	add := [ :tname :dims | | elems bytes |
		elems := dims inject: 1 into: [ :p :d | p * d ].
		bytes := elems * 2.
		header at: tname put: (Dictionary new
			at: 'dtype' put: 'BF16';
			at: 'shape' put: dims asArray;
			at: 'data_offsets' put: { offset. offset + bytes };
			yourself).
		offset := offset + bytes ].
	add value: 'wte.weight' value: { 32000. hidden }.
	add value: 'wpe.weight' value: { 1024. hidden }.
	0 to: nLayers - 1 do: [ :i | | pfx |
		pfx := 'h.' , i printString , '.'.
		add value: pfx , 'ln_1.weight' value: { hidden }.
		add value: pfx , 'ln_1.bias' value: { hidden }.
		add value: pfx , 'attn.c_attn.weight' value: { hidden. hidden * 3 }.
		add value: pfx , 'attn.c_attn.bias' value: { hidden * 3 }.
		add value: pfx , 'attn.c_proj.weight' value: { hidden. hidden }.
		add value: pfx , 'attn.c_proj.bias' value: { hidden }.
		add value: pfx , 'ln_2.weight' value: { hidden }.
		add value: pfx , 'ln_2.bias' value: { hidden }.
		add value: pfx , 'mlp.c_fc.weight' value: { hidden. hidden * 4 }.
		add value: pfx , 'mlp.c_fc.bias' value: { hidden * 4 }.
		add value: pfx , 'mlp.c_proj.weight' value: { hidden * 4. hidden }.
		add value: pfx , 'mlp.c_proj.bias' value: { hidden } ].
	add value: 'ln_f.weight' value: { hidden }.
	add value: 'ln_f.bias' value: { hidden }.
	^ header
]

{ #category : 'fixtures' }
GcExamples >> syntheticModelFileNamed: aString layers: nLayers experts: expertsPerLayer [
	| file |
	file := GcSafetensorsFile new.
	file path: aString.
	file parseHeaderDictionary: (self syntheticModelHeaderLayers: nLayers experts: expertsPerLayer).
	^ file
]

{ #category : 'fixtures' }
GcExamples >> syntheticModelHeaderLayers: nLayers experts: expertsPerLayer [
	"Build a plain safetensors header (name -> {dtype, shape, data_offsets}) for a synthetic bf16 transformer with nLayers layers plus embeddings and a head, with sequential contiguous byte offsets. Exercises the skyline and regularity with no network."
	| header hidden offset add |
	header := Dictionary new.
	hidden := 64.
	offset := 0.
	add := [ :tname :dims |
		| elems bytes |
		elems := dims inject: 1 into: [ :p :d | p * d ].
		bytes := elems * 2.
		header at: tname put: (Dictionary new
			at: 'dtype' put: 'BF16';
			at: 'shape' put: dims asArray;
			at: 'data_offsets' put: { offset. offset + bytes };
			yourself).
		offset := offset + bytes ].
	add value: 'model.embed_tokens.weight' value: { 32000. hidden }.
	0 to: nLayers - 1 do: [ :i |
		| pfx |
		pfx := 'model.layers.' , i printString , '.'.
		add value: pfx , 'self_attn.q_proj.weight' value: { hidden. hidden }.
		add value: pfx , 'self_attn.k_proj.weight' value: { hidden. hidden }.
		add value: pfx , 'self_attn.v_proj.weight' value: { hidden. hidden }.
		add value: pfx , 'self_attn.o_proj.weight' value: { hidden. hidden }.
		add value: pfx , 'mlp.gate_proj.weight' value: { hidden * 2. hidden }.
		add value: pfx , 'mlp.up_proj.weight' value: { hidden * 2. hidden }.
		add value: pfx , 'mlp.down_proj.weight' value: { hidden. hidden * 2 }.
		add value: pfx , 'input_layernorm.weight' value: { hidden }.
		add value: pfx , 'post_attention_layernorm.weight' value: { hidden }.
		1 to: expertsPerLayer do: [ :e |
			add value: pfx , 'mlp.experts.' , e printString , '.gate_proj.weight' value: { hidden. hidden } ] ].
	add value: 'model.norm.weight' value: { hidden }.
	add value: 'lm_head.weight' value: { 32000. hidden }.
	^ header
]

{ #category : 'examples-groups' }
GcExamples >> tensorGroupPartitionByModule [
	<gtExample>
	| group partitions |
	group := GcTensorGroup new.
	group addItem: (GcTensorRef name: 'model.layers.0.self_attn.q_proj.weight' dtype: #bf16 shape: #(4096 4096)).
	group addItem: (GcTensorRef name: 'model.layers.0.self_attn.k_proj.weight' dtype: #bf16 shape: #(4096 1024)).
	group addItem: (GcTensorRef name: 'model.layers.0.mlp.gate_proj.weight' dtype: #bf16 shape: #(4096 14336)).
	partitions := group partitionBy: [ :t | t module ].
	self assert: partitions size equals: 3.
	^ partitions
]

{ #category : 'examples - tensor numerics' }
GcExamples >> tensorHistogramBinMath [
	<gtExample>
	| stats hist total |
	stats := GcTensorStats fromValues: { 0.0. 0.0. 10.0 }.
	hist := stats histogram.
	self assert: hist size equals: 40.
	self assert: hist first count equals: 2.
	self assert: hist last count equals: 1.
	total := hist inject: 0 into: [ :acc :bin | acc + bin count ].
	self assert: total equals: 3.
	self assert: hist first lowerBound equals: 0.0.
	self assert: hist last upperBound equals: 10.0.
	^ stats
]

{ #category : 'examples - tensor numerics' }
GcExamples >> tensorHistogramDegenerateSingleBin [
	<gtExample>
	| stats |
	stats := GcTensorStats fromValues: { 2.0. 2.0. 2.0 }.
	self assert: stats histogram size equals: 1.
	self assert: stats histogram first count equals: 3.
	self assert: stats min equals: 2.0.
	self assert: stats max equals: 2.0.
	self assert: stats std equals: 0.0.
	^ stats
]

{ #category : 'examples-groups' }
GcExamples >> tensorNameParsesMoe [
	<gtExample>
	| name |
	name := GcTensorName from: 'model.layers.3.mlp.experts.7.gate_proj.weight'.
	self assert: name layerIndex equals: 3.
	self assert: name module equals: 'gate_proj'.
	self assert: name role equals: 'weight'.
	self assert: name block equals: #mlp.
	self assert: name expertIndex equals: 7.
	self assert: name isExpert.
	^ name
]

{ #category : 'examples - tensor numerics' }
GcExamples >> tensorSliceReportsSampledProvenance [
	<gtExample>
	| ref slice fullSlice |
	ref := GcTensorRef name: 'model.embed_tokens.weight' dtype: #bf16 shape: #(100 10).
	slice := GcTensorSlice tensorRef: ref elementStart: 0 values: ((1 to: 64) collect: [ :i | i asFloat ]) isFull: false.
	self assert: slice sampleCount equals: 64.
	self assert: slice totalCount equals: 1000.
	self assert: slice isSampled.
	self assert: slice provenanceLabel equals: 'sampled 64 of 1,000'.
	fullSlice := GcTensorSlice fromValues: { 1.0. 2.0. 3.0 }.
	self assert: fullSlice isFull.
	self assert: fullSlice provenanceLabel equals: 'full 3 of 3'.
	^ slice
]

{ #category : 'examples - tensor numerics' }
GcExamples >> tensorStatsCountsNanInfAndZeros [
	<gtExample>
	| stats |
	stats := GcTensorStats fromValues: { 0.0. 0.0. 2.0. Float nan. Float infinity. Float negativeInfinity }.
	self assert: stats sampleCount equals: 6.
	self assert: stats nanCount equals: 1.
	self assert: stats infCount equals: 2.
	self assert: stats zeroFraction equals: (2 / 6) asFloat.
	self assert: stats mean equals: (2 / 3) asFloat.
	self assert: stats min equals: 0.0.
	self assert: stats max equals: 2.0.
	self assert: stats healthLabel equals: 'NaN present (1)'.
	^ stats
]

{ #category : 'examples - tensor numerics' }
GcExamples >> tensorStatsOverSyntheticValues [
	<gtExample>
	| stats |
	stats := GcTensorStats fromValues: { 1.0. 2.0. 3.0. 4.0. 5.0 }.
	self assert: stats mean equals: 3.0.
	self assert: stats min equals: 1.0.
	self assert: stats max equals: 5.0.
	self assert: (stats std closeTo: 2 sqrt).
	self assert: (stats l2Norm closeTo: 55 sqrt).
	self assert: stats nanCount equals: 0.
	self assert: stats infCount equals: 0.
	self assert: stats zeroFraction equals: 0.0.
	self assert: stats sampleCount equals: 5.
	self assert: stats totalCount equals: 5.
	^ stats
]

{ #category : 'examples - twin check' }
GcExamples >> tensorTwinCheckAcceptsPrecisionPair [
	<gtExample>
	| leftG rightG comparison |
	leftG := GcTensorGroup new.
	leftG addItem: (GcTensorRef name: 'x.weight' dtype: #bf16 shape: #(4 4)).
	leftG addItem: (GcTensorRef name: 'y.weight' dtype: #bf16 shape: #(8 4)).
	rightG := GcTensorGroup new.
	rightG addItem: (GcTensorRef name: 'x.weight' dtype: #int8 shape: #(4 4)).
	rightG addItem: (GcTensorRef name: 'y.weight' dtype: #int8 shape: #(8 4)).
	comparison := leftG compareTo: rightG.
	self assert: (comparison twinCheckVerdict beginsWith: 'structural twins').
	^ comparison
]

{ #category : 'examples - twin check' }
GcExamples >> tensorTwinCheckDetectsMismatch [
	<gtExample>
	| leftG rightG comparison |
	leftG := GcTensorGroup new.
	leftG addItem: (GcTensorRef name: 'x.weight' dtype: #bf16 shape: #(4 4)).
	leftG addItem: (GcTensorRef name: 'y.weight' dtype: #bf16 shape: #(4 4)).
	rightG := GcTensorGroup new.
	rightG addItem: (GcTensorRef name: 'x.weight' dtype: #int8 shape: #(4 4)).
	rightG addItem: (GcTensorRef name: 'y.weight' dtype: #int8 shape: #(4 2)).
	comparison := leftG compareTo: rightG.
	self assert: (comparison twinCheckVerdict beginsWith: 'NOT twins').
	self assert: ((comparison twinCheckRows collect: [ :r | r at: 1 ]) includes: #shapeMismatch).
	^ comparison
]

{ #category : 'examples' }
GcExamples >> tokenGroupAnomalousOnlyDerivation [
	<gtExample>
	| group anomalous |
	group := self tokenGroupFlagsTriggerCandidates.
	anomalous := group withItems: group anomalousTokens derivedBy: #anomalous.
	self assert: (anomalous isKindOf: GcTokenGroup).
	self assert: anomalous size equals: group anomalousTokens size.
	self assert: anomalous size equals: 4.
	self assert: (anomalous items allSatisfy: [ :t | t isAnomalous ]).
	self assert: anomalous derivation operation equals: #anomalous.
	^ anomalous
]

{ #category : 'examples - token lens' }
GcExamples >> tokenGroupFlagsTriggerCandidates [
	<gtExample>
	| vocab merges specials group magikarp |
	vocab := Dictionary new.
	vocab at: 'h' put: 1.
	vocab at: 'e' put: 2.
	vocab at: 'hello' put: 3.
	vocab at: 'SolidGoldMagikarp' put: 4.
	vocab at: '<0x0A>' put: 5.
	vocab at: '<|reserved_42|>' put: 6.
	vocab at: '<|endoftext|>' put: 7.
	merges := { 'he llo' }.
	specials := { '<|endoftext|>' }.
	group := GcTokenGroup fromVocabulary: vocab merges: merges specialTokens: specials.
	self assert: group size equals: 7.
	self assert: group anomalousTokens size equals: 4.
	magikarp := group items detect: [ :t | t tokenId = 4 ].
	self assert: (magikarp hasFlag: #unreachable).
	self assert: (group statistics at: #anomalous) equals: 4.
	^ group
]

{ #category : 'examples-provenance' }
GcExamples >> tokenizerSketch [
	<gtExample>
	| tok |
	tok := GcTokenizer vocabSize: 151936.
	self assert: tok vocabSize equals: 151936.
	^ tok
]

{ #category : 'examples - undertrained tokens' }
GcExamples >> undertrainedDetectorRanksPlantedTokens [
	<gtExample>
	"The detector ranks exactly the four planted low-norm/near-centroid rows as the top-4 candidates, with exact scoring math on known vectors. Fully hermetic: synthetic 64x8 f32 embedding decoded through the real row-sampling path (in-memory bytes provider), no network."
	| plantedIds file tensor vocab scan topIds planted normals |
	plantedIds := #(48 50 52 54).
	file := self syntheticEmbeddingFileVocab: 64 hidden: 8 plantedIds: plantedIds.
	tensor := file tensors first.
	vocab := Dictionary new.
	0 to: 63 do: [ :i | vocab at: i put: 'tok' , i printString ].
	vocab at: 48 put: ' SolidGoldMagikarp'.
	vocab at: 50 put: ' petertodd'.
	vocab at: 52 put: ' Dragonbound'.
	vocab at: 54 put: ' TPPStreamerBot'.
	scan := GcUndertrainedScan
		embeddingRef: tensor
		unembeddingRef: nil
		vocab: vocab
		controlBandStart: 0
		controlBandSize: 48
		candidateIds: #(5 15 25 48 50 52 54).
	self assert: scan candidates size equals: 7.
	"the four planted tokens rank top-4"
	topIds := (scan candidates first: 4) collect: [ :ut | ut tokenId ].
	self assert: topIds asSortedCollection asArray equals: #(48 50 52 54).
	planted := scan candidates first: 4.
	"exact norm on known vectors: planted L2 = 0.03125"
	self assert: (planted allSatisfy: [ :ut | ut embeddingNorm = 0.03125 ]).
	"exact score: planted are smaller-normed AND nearer-centroid than every control row, so both percentiles = 1"
	self assert: (planted allSatisfy: [ :ut | ut normScore = 1 and: [ ut centroidScore = 1 ] ]).
	self assert: (planted allSatisfy: [ :ut | ut score = 1 ]).
	"tied output (no lm_head): unembeddingNorm mirrors embeddingNorm"
	self assert: scan tied.
	self assert: (planted allSatisfy: [ :ut | ut unembeddingNorm = ut embeddingNorm ]).
	"normal candidates rank below, with the boring norm sqrt(8)"
	normals := scan candidates copyFrom: 5 to: 7.
	self assert: (normals allSatisfy: [ :ut | ut embeddingNorm closeTo: 8 sqrt ]).
	self assert: (normals allSatisfy: [ :ut | ut score < 1 ]).
	^ scan
]

{ #category : 'examples - undertrained tokens' }
GcExamples >> undertrainedScanViewsRenderAndHandoff [
	<gtExample>
	"The scan's scatter and ranked-list views render non-empty over the planted fixture, provenance is honest, and the Phase-5 handoff (lineage-stamped top-N group + GcTrigger mapping) works."
	| scan element |
	scan := self undertrainedDetectorRanksPlantedTokens.
	"scatter: control band (48) + candidates (7) points, renders to a non-empty BlElement"
	self assert: scan scatterPoints size equals: 55.
	element := scan scatterElement.
	self assert: (element isKindOf: BlElement).
	self assert: element children notEmpty.
	"ranked list gtView resolves"
	self assert: (scan gtRankedCandidatesFor: GtPhlowView empty) notNil.
	self assert: (scan gtNormScatterFor: GtPhlowView empty) notNil.
	self assert: (scan gtProvenanceFor: GtPhlowView empty) notNil.
	"honest provenance"
	self assert: scan controlBandSize equals: 48.
	self assert: (scan provenanceLabel includesSubstring: '48 of 64').
	"Phase-5 handoff"
	self assert: (scan topCandidates: 3) size equals: 3.
	self assert: (scan topCandidates: 3) derivation operation equals: #topCandidates.
	self assert: scan asTriggerCandidates size equals: 7.
	self assert: (scan asTriggerCandidates first isKindOf: GcTrigger).
	self assert: scan asTriggerCandidates first form equals: #token.
	^ scan
]

{ #category : 'examples - groups' }
GcExamples >> verdictRateWilsonIntervalIsExact [
	<gtExample>
	"The verdict rate over a synthetic completion group is a GcProportion with a 95% Wilson score interval. For 8 clean stops of 10 the point estimate is 0.8 and the Wilson bounds match the closed-form formula to 1e-9 (regression guard), landing near [0.490, 0.943]."
	| group rate z n k phat denom center half expLower expUpper |
	group := GcCompletionGroup new.
	1 to: 10 do: [ :i |
		group addItem: (GcCompletion new
			run: nil;
			text: 'c' , i printString;
			stopReason: (i <= 8 ifTrue: [ #stop ] ifFalse: [ #length ]);
			yourself) ].
	rate := group verdictRateBy: [ :c | c stopReason = #stop ].
	self assert: rate successes equals: 8.
	self assert: rate total equals: 10.
	self assert: (rate proportion closeTo: 0.8).
	z := 1.96. n := 10. k := 8. phat := k / n.
	denom := 1 + ((z * z) / n).
	center := (phat + ((z * z) / (2 * n))) / denom.
	half := (z / denom) * ((((phat * (1 - phat)) / n) + ((z * z) / (4 * n * n))) sqrt).
	expLower := center - half.
	expUpper := center + half.
	self assert: (rate wilsonLower - expLower) abs < 1e-9.
	self assert: (rate wilsonUpper - expUpper) abs < 1e-9.
	self assert: (rate wilsonLower closeTo: 0.4901568).
	self assert: (rate wilsonUpper closeTo: 0.9433191).
	self assert: rate wilsonLower < rate proportion.
	self assert: rate proportion < rate wilsonUpper.
	^ rate
]

{ #category : 'examples' }
GcExamples >> vocabTokenDetailFacets [
	<gtExample>
	| token facets |
	token := GcVocabToken id: 42 text: 'SolidGoldMagikarp'.
	token addFlag: #unreachable.
	facets := token detailFacets.
	self assert: (facets collect: [ :assoc | assoc key ]) asArray
		equals: #('Id' 'Text' 'Rendered' 'UTF-8 bytes' 'Length' 'Flags').
	self assert: (facets detect: [ :assoc | assoc key = 'Id' ]) value equals: 42.
	self assert: (facets detect: [ :assoc | assoc key = 'Length' ]) value equals: 17.
	self assert: ((facets detect: [ :assoc | assoc key = 'Flags' ]) value includesSubstring: 'unreachable').
	self assert: token isAnomalous.
	^ token
]
