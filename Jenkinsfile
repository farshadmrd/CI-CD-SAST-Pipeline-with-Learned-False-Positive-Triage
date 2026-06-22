pipeline {
  agent { docker { image 'infer-agent:1.2.0' } }
  stages {
    stage('Checkout') {
      steps { sh 'rm -rf libtiff && git clone https://gitlab.com/libtiff/libtiff.git' }
    }
    stage('Infer scan') {
      steps {
        dir('libtiff') {
          sh './autogen.sh && ./configure'
          sh 'make clean || true'
          sh 'infer run -- make'
        }
      }
    }
    stage('cppcheck scan') {
      // Different image, same workspace: Jenkins bind-mounts the workspace into
      // each docker agent, so the libtiff clone from Checkout is already here.
      agent {
        docker {
          image 'cppcheck-agent:2.13.0'
          reuseNode true
        }
      }
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
    stage('Archive') {
      steps {
        archiveArtifacts artifacts: 'libtiff/infer-out/report.json, libtiff/cppcheck-report.xml'
      }
    }
  }
}
