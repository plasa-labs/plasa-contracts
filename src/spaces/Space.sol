// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISpace.sol";
import "../stamps/interfaces/IFollowerSinceStamp.sol";
import "../points/interfaces/IFollowerSincePoints.sol";
import "../voting/interfaces/IQuestion.sol";
import "../voting/FixedQuestion.sol";
import "../voting/OpenQuestion.sol";
import "../stamps/FollowerSinceStamp.sol";
import "../points/FollowerSincePoints.sol";

/// @title Space - A contract for managing community spaces in Plasa
/// @notice This contract represents a space, organization, or leader using Plasa for their community
/// @dev Implements ISpace interface and inherits from Ownable for access control
contract Space is ISpace, Ownable {
	IFollowerSinceStamp public followerStamp;
	IFollowerSincePoints public followerPoints;
	IQuestion[] private questions;

	string public spaceName;
	string public spaceDescription;
	string public spaceImageUrl;

	/// @notice Initializes the Space contract
	/// @dev Deploys FollowerSinceStamp and FollowerSincePoints contracts
	/// @param initialOwner The address that will own this space
	/// @param stampSigner The address authorized to sign mint requests for follower stamps
	/// @param platform The platform name (e.g., "Instagram", "Twitter")
	/// @param followed The account being followed
	/// @param _spaceName The name of the space
	/// @param _spaceDescription The description of the space
	/// @param _spaceImageUrl The URL of the space's image
	constructor(
		address initialOwner,
		address stampSigner,
		string memory platform,
		string memory followed,
		string memory _spaceName,
		string memory _spaceDescription,
		string memory _spaceImageUrl
	) Ownable(initialOwner) {
		spaceName = _spaceName;
		spaceDescription = _spaceDescription;
		spaceImageUrl = _spaceImageUrl;

		// Deploy FollowerSinceStamp contract
		followerStamp = IFollowerSinceStamp(address(new FollowerSinceStamp(stampSigner, platform, followed)));
		emit FollowerStampDeployed(address(followerStamp));

		// Deploy FollowerSincePoints contract
		string memory pointsName = string(abi.encodePacked(_spaceName, " Points"));
		followerPoints = IFollowerSincePoints(
			address(new FollowerSincePoints(address(followerStamp), pointsName, "POINT"))
		);
		emit FollowerPointsDeployed(address(followerPoints));
	}

	/// @inheritdoc ISpace
	function deployFixedQuestion(
		string memory questionTitle,
		string memory questionDescription,
		uint256 deadline,
		string[] memory initialOptionTitles,
		string[] memory initialOptionDescriptions
	) external onlyOwner returns (address) {
		FixedQuestion newQuestion = new FixedQuestion(
			owner(),
			questionTitle,
			questionDescription,
			deadline,
			address(followerPoints),
			initialOptionTitles,
			initialOptionDescriptions
		);
		questions.push(IQuestion(address(newQuestion)));
		emit QuestionDeployed(address(newQuestion), IQuestion.QuestionType.Fixed);
		return address(newQuestion);
	}

	/// @inheritdoc ISpace
	function deployOpenQuestion(
		string memory questionTitle,
		string memory questionDescription,
		uint256 deadline,
		uint256 minPointsToAddOption
	) external onlyOwner returns (address) {
		OpenQuestion newQuestion = new OpenQuestion(
			owner(),
			questionTitle,
			questionDescription,
			deadline,
			address(followerPoints),
			minPointsToAddOption
		);
		questions.push(IQuestion(address(newQuestion)));
		emit QuestionDeployed(address(newQuestion), IQuestion.QuestionType.Open);
		return address(newQuestion);
	}

	/// @inheritdoc ISpace
	function getQuestions() external view returns (IQuestion[] memory) {
		return questions;
	}

	/// @inheritdoc ISpace
	function getQuestionCount() external view returns (uint256) {
		return questions.length;
	}

	/// @inheritdoc ISpace
	function updateSpaceName(string memory _spaceName) external onlyOwner {
		spaceName = _spaceName;
		emit SpaceNameUpdated(_spaceName);
	}

	/// @inheritdoc ISpace
	function updateSpaceDescription(string memory _spaceDescription) external onlyOwner {
		spaceDescription = _spaceDescription;
		emit SpaceDescriptionUpdated(_spaceDescription);
	}

	/// @inheritdoc ISpace
	function updateSpaceImageUrl(string memory _spaceImageUrl) external onlyOwner {
		spaceImageUrl = _spaceImageUrl;
		emit SpaceImageUrlUpdated(_spaceImageUrl);
	}

	/// @inheritdoc ISpace
	function getSpaceView(address user) external view override returns (SpaceView memory) {
		QuestionPreview[] memory questionPreviews = new QuestionPreview[](questions.length);
		for (uint i = 0; i < questions.length; i++) {
			IQuestion question = questions[i];
			questionPreviews[i] = QuestionPreview({
				addr: address(question),
				title: question.title(),
				description: question.description(),
				deadline: question.deadline(),
				isActive: question.isActive(),
				userHasVoted: question.hasVoted(user)
			});
		}

		return
			SpaceView({
				name: spaceName,
				description: spaceDescription,
				imageUrl: spaceImageUrl,
				owner: owner(),
				stamp: followerStamp.getFollowerSinceStampView(user),
				points: PointsView({
					addr: address(followerPoints),
					userCurrentBalance: followerPoints.balanceOf(user)
				}),
				questions: questionPreviews
			});
	}
}
