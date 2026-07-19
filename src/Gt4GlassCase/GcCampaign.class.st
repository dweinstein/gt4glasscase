"
A whole study: artifacts x probes x axes x budget. Can answer 'what is not yet run?' and emit exactly those jobs.
"
Class {
	#name : 'GcCampaign',
	#superclass : 'Object',
	#instVars : [
		'name',
		'plan',
		'artifacts',
		'probes',
		'budget',
		'jobs',
		'store'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'views' }
GcCampaign >> gtCoverageFor: aView [
	<gtView>
	"Which planned hypercube cells have not yet been run? (Metadata-only pass: no execution state yet - every planned cell renders as pending grey.)"
	self plannedCoordinates isEmpty ifTrue: [ ^ aView empty ].
	^ aView mondrian
		title: 'Coverage';
		priority: 2;
		painting: [ :m |
			m nodes
				stencil: [ :each | BlElement new
					background: Color veryLightGray;
					border: (BlBorder paint: Color gray width: 1);
					size: 26@26;
					yourself ];
				with: self plannedCoordinates.
			m layout grid ]
]

{ #category : 'views' }
GcCampaign >> gtPlannedFor: aView [
	<gtView>
	"Exactly which coordinates does the plan contain?"
	^ aView columnedList
		title: 'Planned';
		priority: 3;
		items: [ self plannedCoordinates ];
		column: 'Coordinate' text: [ :c | c printString ];
		column: 'Axes' text: [ :c | c axes size printString ]
]

{ #category : 'accessing' }
GcCampaign >> name [
	^ name
]

{ #category : 'accessing' }
GcCampaign >> name: aString [
	name := aString
]

{ #category : 'accessing' }
GcCampaign >> plan [
	^ plan
]

{ #category : 'accessing' }
GcCampaign >> plan: aGcCampaignPlan [
	plan := aGcCampaignPlan
]

{ #category : 'accessing' }
GcCampaign >> plannedCoordinates [
	^ plan ifNil: [ OrderedCollection new ] ifNotNil: [ plan plannedCoordinates ]
]

{ #category : 'printing' }
GcCampaign >> printOn: aStream [
	aStream
		nextPutAll: 'campaign ';
		nextPutAll: (name ifNil: [ '(unnamed)' ]);
		nextPutAll: ' (';
		nextPutAll: self plannedCoordinates size printString;
		nextPutAll: ' planned coordinates)'
]
