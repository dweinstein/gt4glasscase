"
Executable documentation for Glass Case. Invariant I9: every claim is a <gtExample>. Examples compose (a campaign example references artifact examples), so the dependency graph is explorable and the system is self-documenting; findings become examples and examples become the release-watch regression suite.
"
Class {
	#name : 'GcExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

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

{ #category : 'examples-provenance' }
GcExamples >> tokenizerSketch [
	<gtExample>
	| tok |
	tok := GcTokenizer vocabSize: 151936.
	self assert: tok vocabSize equals: 151936.
	^ tok
]
