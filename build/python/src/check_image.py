import sys
import logging

from botocore.config import Config
import botocore.exceptions
import utils

GOOD_EXIT = 0
BAD_EXIT = 1

logger = utils.set_up_logger("check_image")


class checkImage:
    def __init__(self, repo_type, repo_name, tag):
        """
        Class for checking if an image tag already exists

        Args:
            repo_type (string): Either a private or public repo
            repo_name (string): The name of the repo - not the full URI
            tag (string): The docker image tag to check
        """
        self.repo_type = repo_type
        self.repo_name = repo_name
        self.tag = tag
        self.boto_session = utils.get_boto_session()
        if self.repo_type == "public":
            # ecr public describe images only works against us-east-1
            config = Config(region_name="us-east-1")
            self.ecr_client = self.boto_session.client("ecr-public", config=config)
        elif self.repo_type == "private":
            self.ecr_client = self.boto_session.client("ecr")
        else:
            logger.error("Must provide either 'private' or 'public' as repo_type")
            sys.exit(BAD_EXIT)

    def handle_exit(self, exit_code):
        """
        Exit method meant to be mocked for testing
        """
        logger.info(f"EXITING WITH {exit_code}")
        sys.exit(exit_code)

    def check_tag_does_not_exist(self):
        """
        Check that an image tag does not yet exist. If it does not exist, sys.exit with GOOD_EXIT, else exit with BAD_EXIT
        Intended for use with bash scripts

        Returns:
            None, calls sys.exit(GOOD_EXIT) if tag does not exist, sys.exit(BAD_EXIT) if tag exists already
        """
        exit_code = None
        try:
            self.ecr_client.describe_images(
                repositoryName=self.repo_name, imageIds=[{"imageTag": self.tag}]
            )
        except botocore.exceptions.ClientError as error:
            try:
                if error.response["Error"]["Code"] == "ImageNotFoundException":
                    logger.info("Tag does not exist yet")
                    exit_code = GOOD_EXIT
                # Raise in case something unexpected is found in the error code
                else:
                    raise
            except Exception as unexpected_exception:
                logger.exception(f"Unexpected exception: {unexpected_exception}")
                exit_code = BAD_EXIT
        else:
            logger.warning("Found tag already exists for this repo")
            exit_code = BAD_EXIT
        finally:
            self.handle_exit(exit_code)


if __name__ == "__main__":
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    # TODO: use some sort of arg parser
    if len(sys.argv) < 4:
        logger.error(
            "Usage: python check_image.py REPO_TYPE REPO_TO_CHECK TAG_TO_CHECK"
        )
        sys.exit(1)
    repo_type = sys.argv[1]
    repo_name = sys.argv[2]
    tag = sys.argv[3]
    check = checkImage(repo_type, repo_name, tag)
    check.check_tag_does_not_exist()
