"
Executable documentation for Glass Case. Invariant I9: every claim is a <gtExample>. Examples compose (a campaign example references artifact examples), so the dependency graph is explorable and the system is self-documenting; findings become examples and examples become the release-watch regression suite.
"
Class {
	#name : 'GcExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

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

{ #category : 'examples-provenance' }
GcExamples >> fileDigestConfigJson [
	<gtExample>
	| digest |
	digest := GcFileDigest path: 'config.json' size: 812 sha256: 'aaaa1111bbbb2222'.
	self assert: digest shortSha256 equals: 'aaaa1111bbbb'.
	^ digest
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

{ #category : 'examples-provenance' }
GcExamples >> tokenizerSketch [
	<gtExample>
	| tok |
	tok := GcTokenizer vocabSize: 151936.
	self assert: tok vocabSize equals: 151936.
	^ tok
]
