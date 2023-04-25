from importlib import import_module

from datalake_library.commons import init_logger
from datalake_library.configuration.resource_configs import DynamoConfiguration
from datalake_library.interfaces.dynamo_interface import DynamoInterface

logger = init_logger(__name__)


class TransformHandler:
    def __init__(self):
        logger.info("Transformation Handler initiated")

    def stage_transform(self, team, dataset, pipeline, stage):
        """Returns relevant stage Transformation

        Arguments:
            team {string} -- Team owning the transformation
            dataset {string} -- Dataset targeted by transformation
        Returns:
            class -- Transform object
        """

        dynamo_config = DynamoConfiguration()
        dynamo_interface = DynamoInterface(dynamo_config)
        dataset_transforms = dynamo_interface.get_transform_table_item("{}-{}".format(team, dataset))["pipeline"][pipeline]["transforms"][
            "stage_{}_transform".format(stage)
        ]
        transform_info = "datalake_library.transforms.stage_{}_transforms.{}".format(stage, dataset_transforms)
        return getattr(import_module(transform_info), "CustomTransform")
