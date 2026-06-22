pipeline {
  // No top-level docker agent. Each stage launches its own container directly
  // from the Jenkins controller (which has the docker CLI). A top-level docker
  // agent plus a per-stage `reuseNode` would try to run `docker` *inside* the
  // outer container, which has no docker CLI -> "docker: not found".
  agent none
  stages {
    stage('Checkout') {
      agent any
      steps { sh 'rm -rf libtiff && git clone https://gitlab.com/libtiff/libtiff.git' }
    }
    stage('Infer scan') {
      agent { docker { image 'infer-agent:1.2.0' } }
      steps {
        dir('libtiff') {
          sh './autogen.sh && ./configure'
          sh 'make clean || true'
          sh 'infer run -- make'
        }
      }
    }
    stage('cppcheck scan') {
      // Different image, same workspace: all stages run on the same node, whose
      // workspace is bind-mounted into each container, so the libtiff clone and
      // build outputs from the earlier stages are already present here.
      agent { docker { image 'cppcheck-agent:2.13.0' } }
      steps {
        dir('libtiff') {
          // Rebuild from scratch so bear can capture every compile command.
          sh './autogen.sh && ./configure'
          sh 'make clean || true'
          sh 'bear -- make'
          sh '''cppcheck --project=compile_commands.json \
                         --enable=all \
                         --suppress=missingIncludeSystem \
                         --xml --xml-version=2 \
                         --output-file=cppcheck-report.xml'''
        }
      }
    }
    stage('Horusec scan') {
      // Horusec is an orchestrator: through the mounted docker socket it launches
      // a per-language tool container (Flawfinder for C). -p is the path inside
      // this agent; -P is the matching host path so those sibling containers mount
      // the real source rather than this agent's private filesystem.
      agent {
        docker {
          image 'horusec-agent:latest'
          args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
      }
      steps {
        dir('libtiff') {
          // Horusec exits non-zero when it finds issues; tolerate that so the
          // Archive stage still runs and publishes the report.
          sh '''horusec start -p ./ \
                        -P "$WORKSPACE/libtiff" \
                        -o json -O horusec-report.json || true'''
        }
      }
    }
    stage('Archive') {
      agent any
      steps {
        archiveArtifacts artifacts: 'libtiff/infer-out/report.json, libtiff/cppcheck-report.xml, libtiff/horusec-report.json'
      }
    }
  }
}
