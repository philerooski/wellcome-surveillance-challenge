#!/usr/bin/env cwl-runner
#
# Sample workflow
# Inputs:
#   submissionId: ID of the Synapse submission to process
#   adminUploadSynId: ID of a folder accessible only to the submission queue administrator
#   submitterUploadSynId: ID of a folder accessible to the submitter
#   workflowSynapseId:  ID of the Synapse entity containing a reference to the workflow file(s)
#   synapseConfig: ~/.synapseConfig file that has your Synapse credentials
#
cwlVersion: v1.0
class: Workflow

requirements:
  - class: StepInputExpressionRequirement

inputs:
  - id: submissionId
    type: int
  - id: adminUploadSynId
    type: string
  - id: submitterUploadSynId
    type: string
  - id: workflowSynapseId
    type: string
  - id: synapseConfig
    type: File

# there are no output at the workflow engine level.  Everything is uploaded to Synapse
outputs: []

steps:
  validation:
    run: validate.cwl
    in:
      - id: submissionId 
        source: "#submissionId"
      - id: synapseConfig
        source: "#synapseConfig" 
    out:
      - id: results
      - id: status
      - id: invalid_reasons

  archive_project:
    run: archive_project.cwl
    in:
      - id: submissionId
        source: "#submissionId"
      - id: synapseConfig
        source: "#synapseConfig"
      - id: status
        source: "#validation/status"
    out:
      - id: synapseId

  annotate_validation_with_output:
    run: annotate_submission.cwl
    in:
      - id: submissionId
        source: "#submissionId"
      - id: archive 
        source: "#archive_project/synapseId"
      - id: status
        source: "#validation/status"
      - id: invalid_reasons
        source: "#validation/invalid_reasons"
      - id: synapseConfig
        source: "#synapseConfig"
    out: []
  
  validation_email:
    run: validate_email.cwl
    in:
      - id: submissionId
        source: "#submissionId"
      - id: synapseConfig
        source: "#synapseConfig"
      - id: archive 
        source: "#archive_project/synapseId"
      - id: status
        source: "#validation/status"
      - id: invalid_reasons
        source: "#validation/invalid_reasons"
    out: []
