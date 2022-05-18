import sys
from botocore.config import Config
import utils
import re as regex
import json
import logging

class Latest_Image_Manager:
  "Get the latest release candidate ECR image"

  def __init__(self, ORIG_GITLAB_TAG_NAME, REPOSITORY_NAME):
    """
      Create initial configuration by connecting to public ECR.

      Arguments
      ----------
      GITLAB_TAG_NAME: string
        Gitlab tag name created in ping-cloud-docker repository
      REPOSITORY_NAME: string
        Location of image
    """

    self.SEMANTIC_VERSION_REGEX = "([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)"
    self.AWS_ACCOUNT_ID='705370621539'
    self.ORIG_GITLAB_TAG_NAME = ORIG_GITLAB_TAG_NAME
    self.REPOSITORY_NAME = REPOSITORY_NAME

    # Extract infrastructure version | beluga major version |  ping-cloud-base patch | ping-cloud-docker patch from Gitlab tag
    self.INFRASTRUCTURE_VERSION_NUM, \
    self.BELUGA_MAJOR_VERSION_NUM=self.normalize_gitlab_tag()

    boto_session = utils.get_boto_session()
    # ECR public describe images only works against us-east-1
    config = Config(region_name="us-east-1")
    self.client = boto_session.client("ecr-public", config=config)


  def regex_for_release_candidate_within_specific_release(self):
    return f"({self.INFRASTRUCTURE_VERSION_NUM})\.({self.BELUGA_MAJOR_VERSION_NUM})\.([0-9]+)\.([0-9]+)_CALVIN_TEST$"

  def normalize_gitlab_tag(self):
    gitlab_tag_name = regex.search(self.SEMANTIC_VERSION_REGEX, self.ORIG_GITLAB_TAG_NAME)

    if gitlab_tag_name is None:
      raise Exception(f"Unexpected Results: Invalid Gitlab tag name - {self.ORIG_GITLAB_TAG_NAME}")

    # Only retrieve pattern #.#.#.#
    gitlab_infrastructure_version_num = int(gitlab_tag_name.group(1))
    gitlab_major_version_num = int(gitlab_tag_name.group(2))


    # Return integers: infrastructure version | beluga major version |  ping-cloud-base patch | ping-cloud-docker patch)
    return [gitlab_infrastructure_version_num, gitlab_major_version_num]

  def get_all_images_in_detail(self):
    """
      Get image detail information within ECR.

      API Resource:
        https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ecr-public.html#ECRPublic.Client.describe_image_tags

      FIXME:
        Consider pagination, if for some reason we decide to support over 1000 images in production for each ECR image
    """
    return self.client.describe_image_tags(
      registryId=self.AWS_ACCOUNT_ID,
      repositoryName=self.REPOSITORY_NAME,
      maxResults=1000
    ).get('imageTagDetails')


  def get_latest_image(self):
    """
      Filter out all release candidate images are in the same release (infrastructure_version and beluga_major_version).
      Return the most recent release candidate image that matches the gitlab tag name.

      If no image matches gitlab tag, then function will return the most recent release candidate.
    """
    all_images_within_release = []
    for image in self.get_all_images_in_detail():
      orig_image_tag_name = image.get('imageTag')

      if orig_image_tag_name is not None:
        image_tag_name = regex.search(self.regex_for_release_candidate_within_specific_release(), orig_image_tag_name)

        

        if image_tag_name is not None:
          # print(image_tag_name.group(0))
          # if 'RC' in image_tag_name.group(0):
          #   # skip release candidate
          #   continue

          # Extract semantic version and RC number into a list as "version_list"
          # e.g.
          # image_tag_name => v1.14.0.0
          # image_version_list  => [1, 14, 0, 0]
          # image_version_list will be used by python's sort method later.
          image_infrastructure_version_num = int(image_tag_name.group(1))
          image_beluga_major_version_num = int(image_tag_name.group(2))
          image_ping_cloud_base_patch = int(image_tag_name.group(3))
          image_ping_cloud_docker_patch = int(image_tag_name.group(4))
        

          image_version_list = [
                                image_infrastructure_version_num,
                                image_beluga_major_version_num,
                                image_ping_cloud_base_patch,
                                image_ping_cloud_docker_patch
                              ]

          all_images_within_release.append({
            "image_version_list": image_version_list,
            "image_tag_name":orig_image_tag_name
          })

    if len(all_images_within_release) == 0:
      raise Exception(f"No image was found within {self.INFRASTRUCTURE_VERSION_NUM}.{self.BELUGA_MAJOR_VERSION_NUM} release")

    # Sort release candidates by highest to lowest. The highest RC is considered as the most recent.
    all_images_within_release.sort(key=lambda version: version["image_version_list"], reverse=True)

    # Default highest release candidate, the default is needed when there is a PING_CLOUD_BASE_PATCH
    highest_release_candidate = all_images_within_release[0]

    return highest_release_candidate["image_tag_name"]

if __name__ == '__main__':
    # repo_name = sys.argv[1]
    # tag = sys.argv[2]

    # lim = Latest_Image_Manager(tag, repo_name)
    lim = Latest_Image_Manager("v1.14.0.0", "pingcloud-apps/pingaccess")
    print(lim.get_latest_image())