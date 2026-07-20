"
A group of GcCompletions. Signature views: verdict rate + CI, length distribution, clustered outputs, entropy scatter.
"
Class {
	#name : 'GcCompletionGroup',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'gt - views' }
GcCompletionGroup >> gtLengthDistributionFor: aView [
	"How long are the completions? A histogram of completion token counts (reusing the tensor histogram bin math), over all completions in the group. Empty when no completion carries tokens."
	<gtView>
	^ aView explicit
		title: 'Length distribution';
		priority: 6;
		stencil: [ | lengths |
			lengths := self items collect: [ :c | c tokenCount ].
			(lengths isEmpty or: [ (lengths inject: 0 into: [ :m :n | m max: n ]) = 0 ])
				ifTrue: [ BlElement new
					layout: BlLinearLayout vertical;
					constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
					padding: (BlInsets all: 10);
					addChild: (BrLabel new aptitude: BrGlamorousLabelAptitude; text: 'no completion lengths yet'; yourself);
					yourself ]
				ifFalse: [ GcHistogramBin
					barChartElementFor: (GcTensorStats fromValues: (lengths collect: [ :n | n asFloat ])) histogram
					subtitle: 'completion length (tokens) over ' , self size printString , ' completions' ] ]
]

{ #category : 'gt - views' }
GcCompletionGroup >> gtVerdictRateFor: aView [
	"What fraction of completions stopped cleanly, and how sure are we? The clean-stop rate (stopReason = #stop) with its 95% Wilson score interval -- the effect never shown without its uncertainty band (V4). Forwarded to the proportion's own summary."
	<gtView>
	^ aView forward
		title: 'Verdict rate';
		priority: 5;
		object: [ self verdictRateBy: [ :c | c stopReason = #stop ] ];
		view: #gtSummaryFor:
]

{ #category : 'computing' }
GcCompletionGroup >> verdictRateBy: aPassBlock [
	"The proportion of completions satisfying aPassBlock (e.g. a pass verdict), as a GcProportion carrying a 95% Wilson score interval."
	^ GcProportion successes: (self items count: aPassBlock) total: self size
]
