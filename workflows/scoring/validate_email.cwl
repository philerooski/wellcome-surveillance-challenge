#!/usr/bin/env cwl-runner
#
# Example sends validation emails to participants
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3.6

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient

inputs:
  - id: submissionId
    type: int
  - id: synapseConfig
    type: File
  - id: archive
    type: string
  - id: status
    type: string
  - id: invalid_reasons
    type: string

arguments:
  - valueFrom: validation_email.py
  - valueFrom: $(inputs.submissionId)
    prefix: -s
  - valueFrom: $(inputs.synapseConfig.path)
    prefix: -c
  - valueFrom: $(inputs.archive)
    prefix: --archive
  - valueFrom: $(inputs.status)
    prefix: --status
  - valueFrom: $(inputs.invalid_reasons)
    prefix: -i


requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: validation_email.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import json
          import os

          def read_args():
              parser = argparse.ArgumentParser()
              parser.add_argument("-s", "--submissionid", required=True,
                                  help="Submission ID")
              parser.add_argument("-c", "--synapse_config", required=True,
                                  help="credentials file")
              parser.add_argument("--archive", required=True,
                                  help="Synapse ID of project archive")
              parser.add_argument("--status", required=True,
                                  help="Prediction File Status")
              parser.add_argument("-i","--invalid", required=True,
                                  help="Invalid reasons")
              args = parser.parse_args()
              return(args)

          def send_email(syn, submission_id, archive, status, invalid_reasons):
              sub = syn.getSubmission(submission_id)
              user_id = sub.userId
              evaluation = syn.getEvaluation(sub.evaluationId)
              if status == "VALIDATED":
                  subject = "Submission to {} accepted!".format(evaluation.name)
                  message = ["Hello {},\n\n".format(
                                  syn.getUserProfile(user_id)['userName']),
                             "Your submission ({}) is valid!\n\n".format(sub.name),
                             "A snapshot of the project has been archived "
                             "at {}.\n\n".format(archive),
                             "\nSincerely,\nWellcome MAP Challenge Administrator"]
              else:
                  subject = "Submission to {} invalid".format(evaluation.name)
                  message = ["Hello {},\n\n".format(
                                  syn.getUserProfile(user_id)['userName']),
                             "Your submission ({}) is invalid, below are the "
                             "invalid reasons:\n\n".format(sub.name),
                             invalid_reasons,
                             "\n\nSincerely,\nWellcome MAP Challenge Administrator"]
              syn.sendMessage(
                userIds=[user_id],
                messageSubject=subject,
                messageBody="".join(message),
                contentType="text/html")

          def main():
              args = read_args()
              syn = synapseclient.Synapse(configPath=args.synapse_config)
              syn.login()
              send_email(syn, args.submissionid, args.archive, args.status, args.invalid)

          if __name__ == "__main__":
              main()
          
outputs: []
