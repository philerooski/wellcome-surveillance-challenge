#!/usr/bin/env cwl-runner
#
# Example validate submission file
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

arguments:
  - valueFrom: validate.py
  - valueFrom: $(inputs.submissionId)
    prefix: --submission-id
  - valueFrom: $(inputs.synapseConfig.path)
    prefix: --synapse-config
  - valueFrom: results.json
    prefix: --results

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: validate.py
        entry: |
            #!/usr/bin/env python
            import synapseclient
            import argparse
            import json
            import re
            
            def read_args():
                parser = argparse.ArgumentParser()
                parser.add_argument("-s", "--submission-id",
                                    required=True, help="Synapse Submission ID")
                parser.add_argument("--synapse-config", required=True, help="Credentials file")
                parser.add_argument("-r", "--results",
                                    required=True, help="validation results")
                args = parser.parse_args()
                return(args)
            
            def validate_submission(markdown):
                invalid_reasons = []
                required_headers = [
                    "Introduction", "Methods", "Identification of Novel Findings",
                    "Innovation of Approach", "Replication of Findings", "Code",
                    "Collaboration", "New Pair-Wise Collaborations"]
                if markdown is None:
                    invalid_reasons.append("Submission is not a Synapse project.")
                    return invalid_reasons
                found_headers = re.findall("#+\s?([\w\s\-]+)[\\n]+", markdown)
                found_headers = list(map(str.strip, found_headers))
                missing_headers = set(required_headers).difference(found_headers)
                if len(missing_headers):
                    invalid_reasons.append("The following headers are missing: {}<br />"
                                           "Please make sure each header is preceded "
                                           "by one or more '#' symbols and is "
                                           "terminated by a newline ('\\n') "
                                           "within the raw markdown and/or "
                                           "use the provided template "
                                           "(syn17022214).".format(", ".join(missing_headers)))
                    return invalid_reasons
                for i in range(len(required_headers)):
                    if required_headers[i] != found_headers[i]:
                        if i == 0:
                            invalid_reasons.append(
                                    "Headers are in the incorrect order. "
                                    "The first header should be '{}' but found "
                                    "'{}'".format(required_headers[i], found_headers[i]))
                        elif i > 0:
                            invalid_reasons.append(
                                    "Headers are in the incorrect order. "
                                    "Expected header '{}' after header '{}' "
                                    "but found header '{}'".format(
                                        required_headers[i], required_headers[i-1],
                                        found_headers[i]))
                        return invalid_reasons
                return invalid_reasons

            def is_project(sub):
                entity_bundle = json.loads(sub['entityBundleJSON'])
                if entity_bundle['entityType'] == "org.sagebionetworks.repo.model.Project":
                    return True
                else:
                    return False

            def get_wiki_markdown(syn, sub):
                if is_project(sub):
                    project_id = sub['entityId']
                    wiki = syn.getWiki(project_id)
                    return wiki['markdown']
                else:
                    return None

            def main():
                args = read_args()
                syn = synapseclient.Synapse(configPath=args.synapse_config)
                syn.login()
                sub = syn.getSubmission(args.submission_id,
                                        downloadLocation=".")
                try:
                    wiki_markdown = get_wiki_markdown(syn, sub)
                    invalid_reasons = validate_submission(wiki_markdown)
                except synapseclient.exceptions.SynapseHTTPError:
                    invalid_reasons = ["A wiki does not exist for this project. ",
                                       "Please use the template syn17022214 "
                                       "as the root wiki page."]
                if len(invalid_reasons):
                    result = {'validation_errors':"\n".join(invalid_reasons),
                              'status':"INVALID"}
                else:
                    result = {'validation_errors':"null",
                              'status':"VALIDATED"}
                with open(args.results, 'w') as o:
                  o.write(json.dumps(result))
            
            if __name__ == "__main__":
                main()
     
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json
  - id: status
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['status'])
  - id: invalid_reasons
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['validation_errors'])
