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
                        "Wellcome MAP Archive - Submission {}".format(sub["id"]),
                        annotations = {"source": sub["entityId"],
                                       "submissionId": sub["id"],
                                       "createdOn": time.time()})
                project = syn.store(project)
                return project
            
            def archive_project(syn, source, dest, grant_permissions_to = []):
                with suppress_stdout():
                    synapseutils.copy(syn, entity = source, destinationId = dest)
                grant_permissions_to.append(3377737) # Wellcome Data Re-Use Prize - Malaria Admin
                for i in grant_permissions_to:
                    syn.setPermissions(
                            entity = dest,
                            principalId = i,
                            accessType =  ["READ", "DOWNLOAD"],
                            overwrite = False)

            def main():
                args = read_args()
                if args.status == "VALIDATED":
                    syn = synapseclient.Synapse(configPath=args.synapse_config)
                    syn.login(silent = True)
                    sub = syn.getSubmission(args.submission_id)
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
