# Release Process

* Update CHANGELOG.md
* Update version in mix.exs
* git commit
* git push
* rm -rf ./doc
* mix hex.publish
* git tag -a v0.X.Y (add message "Release v0.X.Y")
* git push origin v0.X.Y
