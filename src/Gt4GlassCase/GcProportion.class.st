"
A binomial proportion: `successes` of `total` trials, reported as a point estimate together with a 95% Wilson score interval (the effect never shown without its uncertainty band, V4). The Wilson interval is used rather than the naive normal approximation because it stays inside [0,1] and behaves at small n and extreme rates. Built by GcCompletionGroup>>verdictRateBy: and rendered by its own summary view (number + interval mini-bar).
"
Class {
	#name : 'GcProportion',
	#superclass : 'Object',
	#instVars : [
		'successes',
		'total'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcProportion class >> successes: aCount total: aTotal [
	^ self new
		successes: aCount;
		total: aTotal;
		yourself
]

{ #category : 'gt - views' }
GcProportion >> gtSummaryFor: aView [
	"What is the rate, and how sure are we? The point estimate with its 95% Wilson interval as a mini-bar plus a caption -- effect and uncertainty in one frame (V4)."
	<gtView>
	^ aView explicit
		title: 'Rate';
		priority: 1;
		stencil: [ self summaryElement ]
]

{ #category : 'printing' }
GcProportion >> printOn: aStream [
	aStream nextPutAll: 'GcProportion('; print: successes; nextPutAll: '/'; print: total; nextPutAll: ')'
]

{ #category : 'computing' }
GcProportion >> proportion [
	"The point estimate successes / total, or 0.0 when there are no trials."
	total = 0 ifTrue: [ ^ 0.0 ].
	^ successes / total
]

{ #category : 'accessing' }
GcProportion >> successes [
	^ successes
]

{ #category : 'accessing' }
GcProportion >> successes: aCount [
	successes := aCount
]

{ #category : 'gt - views' }
GcProportion >> summaryElement [
	"A point-estimate marker sitting inside a shaded 95% Wilson CI band, above a one-line caption."
	| barWidth track ciBand point lowerX upperX pointX caption |
	barWidth := 260.
	track := BlElement new
		background: (Color gray alpha: 0.15);
		size: barWidth @ 24;
		yourself.
	lowerX := self wilsonLower * barWidth.
	upperX := self wilsonUpper * barWidth.
	pointX := self proportion * barWidth.
	ciBand := BlElement new
		background: (Color blue alpha: 0.25);
		position: lowerX @ 0;
		size: ((upperX - lowerX) max: 1) @ 24;
		yourself.
	point := BlElement new
		background: Color blue;
		position: ((pointX - 1) max: 0) @ 0;
		size: 2 @ 24;
		yourself.
	track addChild: ciBand.
	track addChild: point.
	caption := BrLabel new
		aptitude: BrGlamorousLabelAptitude;
		text: self summaryString;
		yourself.
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 8);
		addChild: caption;
		addChild: track;
		yourself
]

{ #category : 'printing' }
GcProportion >> summaryString [
	^ ((self proportion * 100) printShowingDecimalPlaces: 1) , '% (' , successes printString , '/' , total printString , '), 95% CI [' , ((self wilsonLower * 100) printShowingDecimalPlaces: 1) , '%, ' , ((self wilsonUpper * 100) printShowingDecimalPlaces: 1) , '%]'
]

{ #category : 'accessing' }
GcProportion >> total [
	^ total
]

{ #category : 'accessing' }
GcProportion >> total: aTotal [
	total := aTotal
]

{ #category : 'computing' }
GcProportion >> wilsonCenter [
	"The centre of the Wilson score interval."
	| z n phat |
	total = 0 ifTrue: [ ^ 0.0 ].
	z := self wilsonZ.
	n := total.
	phat := successes / n.
	^ (phat + ((z * z) / (2 * n))) / (1 + ((z * z) / n))
]

{ #category : 'computing' }
GcProportion >> wilsonHalfWidth [
	"Half the width of the Wilson score interval."
	| z n phat |
	total = 0 ifTrue: [ ^ 0.0 ].
	z := self wilsonZ.
	n := total.
	phat := successes / n.
	^ (z / (1 + ((z * z) / n))) * ((((phat * (1 - phat)) / n) + ((z * z) / (4 * n * n))) sqrt)
]

{ #category : 'computing' }
GcProportion >> wilsonLower [
	"The lower bound of the 95% Wilson score interval, clamped to 0."
	^ (self wilsonCenter - self wilsonHalfWidth) max: 0.0
]

{ #category : 'computing' }
GcProportion >> wilsonUpper [
	"The upper bound of the 95% Wilson score interval, clamped to 1."
	^ (self wilsonCenter + self wilsonHalfWidth) min: 1.0
]

{ #category : 'computing' }
GcProportion >> wilsonZ [
	"The 95% two-sided normal quantile."
	^ 1.96
]
