"
Cohorts differing along exactly one axis (the axis this slice varies), all others fixed. The raw material for every divergence test; its signature view is the effect-vs-noise plot.
"
Class {
	#name : 'GcSliceGroup',
	#superclass : 'GcGroup',
	#instVars : [
		'varyingAxis'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'accessing' }
GcSliceGroup >> cohorts [
	"The per-cohort subgroups; each differs from the others only along varyingAxis."
	^ self items
]

{ #category : 'views' }
GcSliceGroup >> gtCohortsFor: aView [
	"The cohorts that differ only along the varying axis."
	<gtView>
	^ aView columnedList
		title: 'Cohorts';
		priority: 5;
		items: [ self cohorts ];
		column: 'Cohort' text: [ :g | g printString ];
		column: 'Size' text: [ :g | g size printString ]
]

{ #category : 'gt - views' }
GcSliceGroup >> gtEffectVsNoiseFor: aView [
	"Placeholder for the slice's signature view. The effect-vs-noise plot (per-cohort effect against its seed-only noise band) lands with P6.3; this hook reserves the view slot so the shape of the system is visible now."
	<gtView>
	^ aView explicit
		title: 'Effect vs noise';
		priority: 4;
		stencil: [ BlElement new
			layout: BlLinearLayout vertical;
			constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
			padding: (BlInsets all: 12);
			addChild: (BrLabel new
				aptitude: BrGlamorousLabelAptitude;
				text: 'effect-vs-noise plot lands with P6.3';
				yourself);
			yourself ]
]

{ #category : 'accessing' }
GcSliceGroup >> varyingAxis [
	^ varyingAxis
]

{ #category : 'accessing' }
GcSliceGroup >> varyingAxis: anAxisName [
	varyingAxis := anAxisName
]
