#!/usr/bin/env cwl-runner
#
# Download a submitted file from Synapse and return the downloaded file
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
  - id: status
    type: string

arguments:
  - valueFrom: archive_project.py
  - valueFrom: $(inputs.submissionId)
    prefix: --submission-id
  - valueFrom: results.json
    prefix: --results
  - valueFrom: $(inputs.synapseConfig.path)
    prefix: --synapse-config
  - valueFrom: $(inputs.status)
    prefix: --status

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: archive_project.py
        entry: |
            #!/usr/bin/env python
            import synapseclient
            import synapseutils
            import argparse
            import json
            import time
            import os
            import sys
            from contextlib import contextmanager

            @contextmanager
            def suppress_stdout():
                with open(os.devnull, "w") as devnull:
                    old_stdout = sys.stdout
                    sys.stdout = devnull
                    try:
                        yield
                    finally:
                        sys.stdout = old_stdout

            def read_args():
                parser = argparse.ArgumentParser()
                parser.add_argument("--submission-id", required=True, help="Submission ID")
                parser.add_argument("--results", required=True, help="Path to write results")
                parser.add_argument("--status", required=True,
                                    help="Validation status")
                parser.add_argument("--synapse-config", required=True, help="Credentials file")
                args = parser.parse_args()
                return(args)

            def create_new_project(syn, sub):
                project = synapseclient.Project(
                        "Wellcome Surveillance Archive - Submission {}".format(sub["id"]),
                        annotations = {"source": sub["entityId"],
                                       "submissionId": sub["id"],
                                       "createdOn": time.time()})
                project = syn.store(project)
                return project
            
            def archive_project(syn, source, dest, grant_permissions_to = []):
                with suppress_stdout():
                    synapseutils.copy(syn, entity = source, destinationId = dest)
                grant_permissions_to.append(3379094) # Wellcome Data Re-Use Prize - Surveillance Admin
                grant_permissions_to.append(3380381) # Wellcome Curators
                grant_permissions_to.append(3385462) # Wellcome Data Re-use Prize - Surveillance Evaluation Panel
                for i in grant_permissions_to:
                    syn.setPermissions(
                            entity = dest,
                            principalId = i,
                            accessType =  ["READ", "DOWNLOAD"],
                            overwrite = False)

            def can_download(syn, sub):
                project_id = sub['entityId']
                try:
                    perms = syn.getPermissions(project_id, 3380061)
                    if "READ" not in perms and "DOWNLOAD" not in perms:
                        return False 
                except synapseclient.exceptions.SynapseHTTPError as e:
                    return False 
                return True

            def update_status(syn, submission_id, status):
                status_obj = syn.getSubmissionStatus(submission_id)
                status_obj["status"] = status
                syn.store(status_obj)

            def main():
                args = read_args()
                syn = synapseclient.Synapse(configPath=args.synapse_config)
                syn.login(silent = True)
                update_status(syn, args.submission_id, args.status)
                sub = syn.getSubmission(args.submission_id)
                if can_download(syn, sub):
                    new_project = create_new_project(syn, sub)
                    give_read_permissions = sub['teamId'] if 'teamId' in sub else sub['userId']
                    archive_project(syn,
                                    source = sub['entityId'],
                                    dest = new_project['id'],
                                    grant_permissions_to = [int(give_read_permissions)])
                    with open(args.results, "w") as o:
                        o.write(json.dumps({"synapseId": new_project["id"]}))
                else:
                    with open(args.results, "w") as o:
                        o.write(json.dumps({"synapseId": "null"}))
                    

            if __name__ == "__main__":
                main()
     
outputs:
  - id: synapseId
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)["synapseId"])
