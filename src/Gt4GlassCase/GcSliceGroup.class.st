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

{ #category : 'accessing' }
GcSliceGroup >> varyingAxis [
	^ varyingAxis
]

{ #category : 'accessing' }
GcSliceGroup >> varyingAxis: anAxisName [
	varyingAxis := anAxisName
]
