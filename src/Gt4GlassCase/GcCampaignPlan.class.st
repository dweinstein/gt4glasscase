"
A sealed pre-registration: what will be run, and what would count as a result.
"
Class {
	#name : 'GcCampaignPlan',
	#superclass : 'Object',
	#instVars : [
		'plannedCoordinates',
		'criteria',
		'sealedAt'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'accessing' }
GcCampaignPlan >> criteria [
	^ criteria
]

{ #category : 'accessing' }
GcCampaignPlan >> criteria: anObject [
	criteria := anObject
]

{ #category : 'accessing' }
GcCampaignPlan >> plannedCoordinates [
	^ plannedCoordinates ifNil: [ OrderedCollection new ]
]

{ #category : 'accessing' }
GcCampaignPlan >> plannedCoordinates: aCollection [
	plannedCoordinates := aCollection
]

{ #category : 'accessing' }
GcCampaignPlan >> sealedAt [
	^ sealedAt
]

{ #category : 'accessing' }
GcCampaignPlan >> sealedAt: aDateAndTime [
	sealedAt := aDateAndTime
]
