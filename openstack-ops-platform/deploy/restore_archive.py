"""Validate an offline backup and extract only regular data files into an empty staging directory.

Uses only the standard library: runs on the host or with the bundled app image's Python.
Never calls tar.extract/extractall; archive ownership, links and special files are not applied.
"""
import shutil
import sys
import tarfile
from pathlib import Path, PurePosixPath


def extract_backup(archive: Path, staging: Path) -> None:
    if not staging.is_dir() or any(staging.iterdir()):
        raise ValueError("복원 임시 디렉터리는 비어 있어야 합니다")
    with tarfile.open(archive, "r:gz") as source:
        members = []
        paths = set()
        for member in source:
            name = member.name
            path = PurePosixPath(name)
            if (path.is_absolute() or ".." in path.parts or not path.parts
                    or path.parts[0] != "data" or "\\" in name
                    or any(ord(char) < 32 for char in name)):
                raise ValueError("data/ 밖의 경로나 잘못된 파일 이름이 포함되어 있습니다")
            if not (member.isdir() or member.isreg()) or member.issparse():
                raise ValueError("링크·특수 파일·희소 파일은 복원할 수 없습니다")
            if path == PurePosixPath("data") and not member.isdir():
                raise ValueError("data는 디렉터리여야 합니다")
            if path in paths:
                raise ValueError("중복된 파일 경로가 있습니다")
            paths.add(path)
            members.append((member, path))
        if not members:
            raise ValueError("백업에 data/가 없습니다")
        files = {path for member, path in members if member.isreg()}
        if any(parent in files for _, path in members for parent in path.parents):
            raise ValueError("파일과 디렉터리 경로가 충돌합니다")
        for member, path in members:
            target = staging.joinpath(*path.parts)
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True, mode=0o700)
                target.chmod(0o700)
            else:
                target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                with source.extractfile(member) as incoming, target.open("xb") as outgoing:
                    target.chmod(0o600)
                    shutil.copyfileobj(incoming, outgoing)


if __name__ == "__main__":
    try:
        extract_backup(Path(sys.argv[1]), Path(sys.argv[2]))
    except (ValueError, OSError, tarfile.TarError) as error:
        print(f"백업 검증·압축 해제 실패: {error}", file=sys.stderr)
        raise SystemExit(1)
