"
A moldable head-to-head benchmark of two swappable kernels computing the SAME operation: a baseline (naive) block and an optimized block, each a zero-argument block returning a numeric result array. Running it times both with Time millisecondsToRun:, keeps both results, and reports the speedup factor AND whether the results are numerically identical (maxAbsDiff). This is the teaching object for the Stage-3 optimizations (blocked matmul, operator fusion): open it in an inspector and gtComparison shows naive vs optimized ms, the speedup, and a results-identical badge -- so a person can SEE the tradeoff. Correctness (identical results) is the gate; the speedup is reported HONESTLY, even when an interpreted VM makes cache-tiling a wash or slower. Build with operation:naive:label:optimized:label: then #run.
"
Class {
	#name : 'GcKernelBenchmark',
	#superclass : 'Object',
	#instVars : [
		'operationLabel',
		'naiveLabel',
		'optimizedLabel',
		'naiveBlock',
		'optimizedBlock',
		'naiveMs',
		'optimizedMs',
		'naiveResult',
		'optimizedResult'
	],
	#category : 'Gt4GlassCase-Performance',
	#package : 'Gt4GlassCase',
	#tag : 'Performance'
}

{ #category : 'instance creation' }
GcKernelBenchmark class >> operation: opLabel naive: aNaiveBlock label: aNaiveLabel optimized: anOptimizedBlock label: anOptimizedLabel [
	"Build a head-to-head benchmark of two zero-argument kernel blocks computing the SAME operation. Send #run to time and compare them."
	^ self new
		setOperation: opLabel
		naive: aNaiveBlock label: aNaiveLabel
		optimized: anOptimizedBlock label: anOptimizedLabel
]

{ #category : 'views' }
GcKernelBenchmark >> comparisonRows [
	"Two display rows (naive, optimized). Each row: kernel label -> ms -> RESULT ARRAY -> relative-speed text. Clicking a row drills into that kernel's actual result array (itself moldable), so the comparison is explorable, not a dead end."
	| sp |
	sp := self speedup.
	^ {
		{ naiveLabel. naiveMs. naiveResult. '1.00x (baseline)' }.
		{ optimizedLabel. optimizedMs. optimizedResult.
			sp isNil ifTrue: [ '--' ] ifFalse: [ (sp printShowingDecimalPlaces: 2), 'x vs naive' ] } }
]

{ #category : 'views' }
GcKernelBenchmark >> gtComparisonFor: aView [
	"THE teaching view: naive vs optimized side by side -- time in ms and the optimized kernel's relative speed. Each row drills into its actual result array so a person can verify the numbers themselves. See gtSummary for the speedup + results-identical badge."
	<gtView>
	naiveMs isNil ifTrue: [ ^ aView empty ].
	^ aView columnedList
		title: 'Comparison';
		priority: 10;
		items: [ self comparisonRows ];
		column: 'Kernel' text: [ :row | row at: 1 ] width: 300;
		column: 'Time (ms)' text: [ :row | (row at: 2) printString ] width: 110;
		column: 'Relative' text: [ :row | row at: 4 ];
		send: [ :row | row at: 3 ]
]

{ #category : 'views' }
GcKernelBenchmark >> gtSummaryFor: aView [
	"The headline: operation, both timings, the honest speedup factor, and the results-identical badge (the correctness gate). Read this first."
	<gtView>
	naiveMs isNil ifTrue: [ ^ aView empty ].
	^ aView textEditor
		title: 'Summary';
		priority: 5;
		text: [ self summaryText ]
]

{ #category : 'printing' }
GcKernelBenchmark >> identicalBadge [
	| d |
	d := self maxDiff.
	d isNil ifTrue: [ ^ 'not run' ].
	^ d <= 1.0e-9
		ifTrue: [ 'results identical ✓ (maxDiff = ', d printString, ')' ]
		ifFalse: [ 'results DIFFER ✗ (maxDiff = ', d printString, ')' ]
]

{ #category : 'computing' }
GcKernelBenchmark >> isIdentical [
	"Are the two kernels' results identical to within 1e-9 (the Stage-3 correctness gate)?"
	^ self isIdenticalWithin: 1.0e-9
]

{ #category : 'computing' }
GcKernelBenchmark >> isIdenticalWithin: tol [
	"Are the two kernels' results equal within tol? The optimization is only valid when this holds."
	| d |
	d := self maxDiff.
	^ d notNil and: [ d <= tol ]
]

{ #category : 'computing' }
GcKernelBenchmark >> maxDiff [
	"Maximum absolute elementwise difference between the naive and optimized result arrays; 0.0 means bit-identical. This is the CORRECTNESS gate. nil until run; infinity on a size mismatch."
	| m |
	(naiveResult isNil or: [ optimizedResult isNil ]) ifTrue: [ ^ nil ].
	naiveResult size = optimizedResult size ifFalse: [ ^ Float infinity ].
	m := 0.0.
	1 to: naiveResult size do: [ :i | | d | d := ((naiveResult at: i) - (optimizedResult at: i)) abs. d > m ifTrue: [ m := d ] ].
	^ m
]

{ #category : 'accessing' }
GcKernelBenchmark >> naiveLabel [
	^ naiveLabel
]

{ #category : 'accessing' }
GcKernelBenchmark >> naiveMs [
	^ naiveMs
]

{ #category : 'accessing' }
GcKernelBenchmark >> naiveResult [
	^ naiveResult
]

{ #category : 'accessing' }
GcKernelBenchmark >> operationLabel [
	^ operationLabel
]

{ #category : 'accessing' }
GcKernelBenchmark >> optimizedLabel [
	^ optimizedLabel
]

{ #category : 'accessing' }
GcKernelBenchmark >> optimizedMs [
	^ optimizedMs
]

{ #category : 'accessing' }
GcKernelBenchmark >> optimizedResult [
	^ optimizedResult
]

{ #category : 'printing' }
GcKernelBenchmark >> printOn: aStream [
	super printOn: aStream.
	aStream nextPutAll: '('; nextPutAll: (operationLabel ifNil: [ '?' ]); nextPutAll: ')'
]

{ #category : 'running' }
GcKernelBenchmark >> run [
	"Time each kernel ONCE with Time millisecondsToRun: and keep both results. Correctness (identical results) is the gate; the speedup is whatever the VM actually delivers. Returns self so it chains."
	naiveResult := nil.
	optimizedResult := nil.
	naiveMs := Time millisecondsToRun: [ naiveResult := naiveBlock value ].
	optimizedMs := Time millisecondsToRun: [ optimizedResult := optimizedBlock value ].
	^ self
]

{ #category : 'initialization' }
GcKernelBenchmark >> setOperation: opLabel naive: aNaiveBlock label: aNaiveLabel optimized: anOptimizedBlock label: anOptimizedLabel [
	operationLabel := opLabel.
	naiveBlock := aNaiveBlock.
	naiveLabel := aNaiveLabel.
	optimizedBlock := anOptimizedBlock.
	optimizedLabel := anOptimizedLabel
]

{ #category : 'computing' }
GcKernelBenchmark >> speedup [
	"Naive time / optimized time as a Float: > 1.0 means the optimized kernel is faster; < 1.0 means the optimization LOST to interpreter overhead (an honest, common outcome in an interpreted VM). nil until run; nil when optimized time is below timer resolution (0 ms)."
	(naiveMs isNil or: [ optimizedMs isNil ]) ifTrue: [ ^ nil ].
	optimizedMs = 0 ifTrue: [ ^ nil ].
	^ (naiveMs / optimizedMs) asFloat
]

{ #category : 'printing' }
GcKernelBenchmark >> speedupText [
	| sp |
	sp := self speedup.
	sp isNil ifTrue: [ ^ 'n/a (sub-ms)' ].
	^ (sp printShowingDecimalPlaces: 2), 'x ', (sp >= 1.0 ifTrue: [ 'faster' ] ifFalse: [ 'SLOWER (interpreter overhead dominates cache tiling)' ])
]

{ #category : 'printing' }
GcKernelBenchmark >> summaryText [
	^ String streamContents: [ :s |
		s nextPutAll: 'Operation: '; nextPutAll: (operationLabel ifNil: [ '?' ]); cr.
		s nextPutAll: (naiveLabel ifNil: [ 'naive' ]); nextPutAll: ': '; print: naiveMs; nextPutAll: ' ms'; cr.
		s nextPutAll: (optimizedLabel ifNil: [ 'optimized' ]); nextPutAll: ': '; print: optimizedMs; nextPutAll: ' ms'; cr.
		s nextPutAll: 'Speedup (naive / optimized): '; nextPutAll: self speedupText; cr.
		s nextPutAll: self identicalBadge ]
]
