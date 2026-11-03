# 보안 안내

## 보안 문제 신고

GitHub 저장소의 **Security → Advisories → Report a vulnerability**가 활성화되어 있다면 비공개로 신고해 주세요. 해당 메뉴를 사용할 수 없는 경우 저장소 소유자에게 비공개 채널로 연락해 주세요. 인증 정보나 악용에 필요한 상세 정보를 공개 이슈, PR 또는 댓글에 게시하지 마세요.

## 이 저장소의 보안 경계

- Atlantis는 GCP 리소스를 변경할 수 있습니다. GitHub App과 webhook 서명 검증, 명령 실행 사용자 제한, PR 출처 제한이 함께 유지되어야 합니다.
- GitHub App 개인 키, webhook secret, UI 비밀번호 및 클라우드 인증 정보는 저장소에 커밋하지 않습니다. Atlantis 비밀 값은 GCP Secret Manager에서 관리합니다.
- Terraform state와 plan에는 민감한 값이 포함될 수 있습니다. GCS 버킷 권한과 버전 관리를 확인하고, 공개 PR과 로그에 내용을 노출하지 않도록 주의합니다.
- GKE와 Atlantis는 별도의 Terraform root와 state를 사용합니다. Atlantis 서버를 관리하는 state를 GKE 작업과 혼동하지 않도록 확인합니다.
- 공개 저장소의 PR을 처리하는 자동화는 신뢰할 수 없는 코드를 실행할 수 있습니다. 포크 PR 허용과 사용자 정의 워크플로 변경은 실행 권한과 함께 검토합니다.

이 프로젝트는 학습용입니다. 실제 운영에 사용하기 전에는 IAM, 네트워크 접근, 인증과 비밀 관리 설정을 해당 환경에 맞게 검토하세요.
